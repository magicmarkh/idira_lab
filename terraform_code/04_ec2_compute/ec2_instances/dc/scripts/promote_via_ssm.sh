#!/usr/bin/env bash
#
# promote_via_ssm.sh
# ------------------
# Drives the Ansible domain_controller role against the private DC from outside
# the VPC, using an AWS SSM port-forwarding session (no inbound ports, no VPN).
#
# Opens localhost:${LOCAL_PORT} -> DC:5985 over SSM, waits for the tunnel, runs
# the setup_domain_controller.yml playbook against 127.0.0.1, then tears the
# session down.
#
# IMPORTANT: promotion reboots the DC, which drops the SSM session. The tunnel
# therefore runs in a KEEPALIVE LOOP that re-establishes the port-forward as
# soon as the SSM agent comes back after the reboot. From Ansible's point of
# view (127.0.0.1:${LOCAL_PORT}) the connection simply drops and returns, which
# is exactly what microsoft.ad.domain's reboot/reconnect handling expects.
#
# All inputs arrive via environment variables (set by the Terraform local-exec
# provisioner) so secrets never appear in this script's argv. Secrets are written
# to a mode-0600 temp extra-vars file and removed on exit.
#
# Prerequisites on the machine running `terraform apply`:
#   - aws CLI + session-manager-plugin, with credentials allowing ssm:StartSession
#   - ansible + pywinrm
set -euo pipefail

: "${SSM_INSTANCE_ID:?SSM_INSTANCE_ID is required}"
: "${AWS_REGION:?AWS_REGION is required}"
: "${ANSIBLE_DIR:?ANSIBLE_DIR is required}"
: "${DC_ADMIN_PASSWORD:?DC_ADMIN_PASSWORD is required}"
: "${DC_DOMAIN_FQDN:?DC_DOMAIN_FQDN is required}"
: "${DC_DOMAIN_NETBIOS:?DC_DOMAIN_NETBIOS is required}"
: "${DC_DSRM_PASSWORD:?DC_DSRM_PASSWORD is required}"
: "${DC_SERVICE_ACCOUNT_NAME:?DC_SERVICE_ACCOUNT_NAME is required}"
: "${DC_SERVICE_ACCOUNT_PASSWORD:?DC_SERVICE_ACCOUNT_PASSWORD is required}"

LOCAL_PORT="${LOCAL_PORT:-55985}"
REMOTE_PORT=5985

# Use the credentials Terraform passed in (Conjur-sourced in API mode) instead of
# the operator's ambient shell credentials, which are frequently stale after the
# automation key is rotated. Only override when BOTH are present; otherwise fall
# through to the default chain (e.g. the EC2 instance role in IAM mode).
if [[ -n "${AWS_ACCESS_KEY_ID_OVERRIDE:-}" && -n "${AWS_SECRET_ACCESS_KEY_OVERRIDE:-}" ]]; then
  export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID_OVERRIDE"
  export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY_OVERRIDE"
  unset AWS_SESSION_TOKEN
  echo "[promote_dc] Using Terraform-provided AWS credentials for SSM."
else
  echo "[promote_dc] No credential override supplied; using the ambient AWS credential chain."
fi
SSM_LOG="$(mktemp -t ssm_promote.XXXXXX.log)"
VARS_FILE="$(mktemp -t dc_vars.XXXXXX.yml)"
STOP_FILE="$(mktemp -t ssm_stop.XXXXXX)"
chmod 600 "$VARS_FILE"
# STOP_FILE presence = "shutting down"; remove it now so the loop runs.
rm -f "$STOP_FILE"

TUNNEL_PID=""
cleanup() {
  : >"$STOP_FILE" 2>/dev/null || true
  # Kill any live port-forward session for THIS target, plus the keepalive loop.
  pkill -f "start-session.*${SSM_INSTANCE_ID}" 2>/dev/null || true
  if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
    kill "$TUNNEL_PID" 2>/dev/null || true
    wait "$TUNNEL_PID" 2>/dev/null || true
  fi
  rm -f "$VARS_FILE" "$SSM_LOG" "$STOP_FILE"
}
trap cleanup EXIT

# Keepalive tunnel: (re)start the port-forward until asked to stop. Each
# start-session blocks until the session ends (drop or DC reboot); we then
# reconnect after a short pause. start-session naturally retries while the DC
# is rebooting and the SSM agent is unreachable.
tunnel_loop() {
  while [[ ! -e "$STOP_FILE" ]]; do
    aws ssm start-session \
      --region "$AWS_REGION" \
      --target "$SSM_INSTANCE_ID" \
      --document-name AWS-StartPortForwardingSession \
      --parameters "{\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}" \
      >>"$SSM_LOG" 2>&1 || true
    [[ -e "$STOP_FILE" ]] && break
    sleep 3
  done
}

# The Administrator password (DC_ADMIN_PASSWORD) is decrypted in Terraform from the
# EC2-generated blob using the Conjur-vaulted PEM and passed in via the environment,
# so no client-side get-password-data call is needed here.

echo "[promote_dc] Starting keepalive SSM port-forward ${LOCAL_PORT} -> ${SSM_INSTANCE_ID}:${REMOTE_PORT} (region ${AWS_REGION})"
tunnel_loop &
TUNNEL_PID=$!

echo "[promote_dc] Waiting for 127.0.0.1:${LOCAL_PORT} to accept connections ..."
for i in $(seq 1 60); do
  if (exec 3<>"/dev/tcp/127.0.0.1/${LOCAL_PORT}") 2>/dev/null; then
    exec 3>&- 3<&- || true
    echo "[promote_dc] Tunnel is up."
    break
  fi
  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    echo "[promote_dc] Tunnel loop exited early. Log:"; cat "$SSM_LOG" || true
    exit 1
  fi
  if [[ "$i" -eq 60 ]]; then
    echo "[promote_dc] Timed out waiting for the SSM tunnel."; cat "$SSM_LOG" || true
    exit 1
  fi
  sleep 5
done

# Extra-vars written to a 0600 temp file so passwords stay out of process argv.
cat >"$VARS_FILE" <<YAML
ansible_host: 127.0.0.1
ansible_port: ${LOCAL_PORT}
ansible_user: Administrator
ansible_password: "${DC_ADMIN_PASSWORD}"
ansible_connection: winrm
ansible_winrm_scheme: http
# NTLM (not basic): WinRM basic auth only validates LOCAL accounts. After the
# forest is promoted the DC has no local accounts and Administrator becomes the
# DOMAIN admin, so basic auth 401s on the post-reboot reconnect. NTLM works for
# both the pre-promotion local admin and the post-promotion domain admin, and
# encrypts the payload over HTTP. Enable-PSRemoting already enables Negotiate on
# the listener, so no instance/user_data change is needed.
ansible_winrm_transport: ntlm
ansible_winrm_server_cert_validation: ignore
dc_domain_fqdn: "${DC_DOMAIN_FQDN}"
dc_domain_netbios: "${DC_DOMAIN_NETBIOS}"
dc_dsrm_password: "${DC_DSRM_PASSWORD}"
dc_service_account_name: "${DC_SERVICE_ACCOUNT_NAME}"
dc_service_account_password: "${DC_SERVICE_ACCOUNT_PASSWORD}"
YAML

cd "$ANSIBLE_DIR"

echo "[promote_dc] Installing required Ansible collections ..."
ansible-galaxy collection install -r requirements.yml

echo "[promote_dc] Running the domain controller playbook ..."
ansible-playbook -i '127.0.0.1,' -e "@${VARS_FILE}" playbooks/setup_domain_controller.yml

echo "[promote_dc] Domain controller build complete."
