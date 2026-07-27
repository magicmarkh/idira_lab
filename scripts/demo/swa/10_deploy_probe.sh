#!/bin/bash
# Deploy the swa-probe and show it obtain a JWT-SVID from the SWA agent.
# Proves workload identity works BEFORE Secrets Manager is involved.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

step "Deploying swa-probe"
run_remote "kubectl apply -f ${SWA_DIR}/swa-probe.rendered.yaml"

step "Waiting for the probe pod to be Ready"
run_remote "kubectl -n ${PROBE_NS} wait --for=condition=Ready pod -l app=swa-probe --timeout=120s"

step "Probe output (SPIFFE identity + JWT-SVID claims)"
# Narrate only the interesting lines.
run_remote "kubectl -n ${PROBE_NS} logs deploy/swa-probe --tail=40 2>&1" \
  | grep --line-buffered -E 'SUCCESS|sub|aud|iss|exp' || true

echo ""
if run_remote "kubectl -n ${PROBE_NS} logs deploy/swa-probe --tail=40 2>&1" \
     | grep -q 'SUCCESS: fetched a JWT-SVID'; then
  ok_banner "PROBE SUCCESS — workload identity is working"
else
  err_banner "PROBE did not report success — check the SWA agent socket"
  echo "  Tip: docker exec ${KIND_NODE_CONTAINER} ls -l ${SWA_SOCKET_PATH}"
  exit 1
fi
