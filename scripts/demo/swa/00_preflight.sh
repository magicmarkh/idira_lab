#!/bin/bash
# Preflight: verify the SWA environment is ready to demo (read-only).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

FAIL=0
check() {
  # check <label> <remote-cmd...>
  local label="$1"; shift
  if run_remote "$@" >/dev/null 2>&1; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} ${label}"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} ${label}"
    FAIL=1
  fi
}

step "Preflight against kind node ${KIND_NODE_IP}"

check "SSH reachable"                        "echo ok"
check "kind cluster nodes Ready"             "kubectl get nodes | grep -q ' Ready '"
check "SWA agent DaemonSet present"          "kubectl -n ${SWA_AGENT_NS} get ds >/dev/null 2>&1"
check "SWA agent socket present on node"     "docker exec ${KIND_NODE_CONTAINER} ls ${SWA_SOCKET_PATH}"
check "swa-probe image loaded"               "docker images | grep -q swa-probe"
check "fetch-secret image loaded"            "docker images | grep -q fetch-secret"
check "go.sum generated (swa_probe)"         "test -f ${SWA_DIR}/swa_probe/go.sum"
check "rendered manifests present"           "test -f ${SWA_DIR}/fetch-secret-job.rendered.yaml"

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  ok_banner "PREFLIGHT PASSED — ready to demo"
else
  err_banner "PREFLIGHT FAILED — re-run the setup_swa_workloads playbook"
  echo "  (terraform apply with enable_swa_workloads=true, or run the playbook directly)"
  exit 1
fi
