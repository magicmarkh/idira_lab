#!/bin/bash
# HEADLINE DEMO: the fetch-secret Job runs the full round trip —
# workload identity (JWT-SVID) -> Secrets Manager JWT auth -> read a live secret.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

# A Job can't be re-applied while an old one exists — reset first if present.
if run_remote "kubectl -n ${PROBE_NS} get job fetch-secret" >/dev/null 2>&1; then
  step "Existing fetch-secret Job found — resetting"
  "${SCRIPT_DIR}/30_reset.sh"
fi

step "Applying fetch-secret Job"
run_remote "kubectl apply -f ${SWA_DIR}/fetch-secret-job.rendered.yaml"

step "Waiting for the Job to complete"
if ! run_remote "kubectl -n ${PROBE_NS} wait --for=condition=complete job/fetch-secret --timeout=90s" 2>/dev/null; then
  err_banner "fetch-secret did NOT complete"
  echo "Recent logs:"
  run_remote "kubectl -n ${PROBE_NS} logs job/fetch-secret --tail=40 2>&1" || true
  echo ""
  echo -e "${COLOR_YELLOW}Triage:${COLOR_RESET}"
  echo "  401/404 on /authn-jwt/  -> authenticator not enabled or sub mismatch"
  echo "  403 on /secrets/        -> missing read grant (grant-read.yml)"
  echo "  JWKS/signature error    -> wrong JWKS URI in the authenticator config"
  exit 1
fi

step "Result"
run_remote "kubectl -n ${PROBE_NS} logs job/fetch-secret 2>&1"

echo ""
ok_banner "END-TO-END SUCCESS — secret retrieved via workload identity"
