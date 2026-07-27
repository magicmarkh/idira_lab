#!/bin/bash
# Reset for a repeat demo.
#   (default)  delete the fetch-secret Job so it can be re-applied
#   --full     also delete the probe Deployment and re-apply it
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

FULL=0
[[ "${1:-}" == "--full" ]] && FULL=1

step "Deleting fetch-secret Job"
run_remote "kubectl -n ${PROBE_NS} delete job fetch-secret --ignore-not-found"

if [[ "${FULL}" -eq 1 ]]; then
  step "Full reset — redeploying swa-probe"
  run_remote "kubectl -n ${PROBE_NS} delete deploy swa-probe --ignore-not-found"
  run_remote "kubectl apply -f ${SWA_DIR}/swa-probe.rendered.yaml"
fi

ok_banner "RESET COMPLETE — ready to re-run"
