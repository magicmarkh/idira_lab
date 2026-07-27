#!/bin/bash
# Shared config for the SWA presenter demo scripts.
# Run these from the automation server (in the same private subnet as the kind
# node); they SSH to the node using the same pem the Terraform provisioners use.
#
# Required env (or edit the defaults):
#   KIND_NODE_IP   private IP of the kind node
#   KIND_SSH_KEY   path to the ec2 pem (ec2-user)
#
# Optional:
#   PROBE_NS       namespace (default swa-probe)
#   SWA_DIR        node path where the role rendered manifests (default ~/swa)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$(cd "${SCRIPT_DIR}/../../" && pwd)/config.sh"   # repo scripts/config.sh (colors, REPO_ROOT)

export KIND_NODE_IP="${KIND_NODE_IP:?set KIND_NODE_IP to the kind node private IP}"
export KIND_SSH_KEY="${KIND_SSH_KEY:?set KIND_SSH_KEY to the ec2 pem path}"
export KIND_SSH_USER="${KIND_SSH_USER:-ec2-user}"
export PROBE_NS="${PROBE_NS:-swa-probe}"
export SWA_DIR="${SWA_DIR:-/home/${KIND_SSH_USER}/swa}"
export KIND_NODE_CONTAINER="${KIND_NODE_CONTAINER:-kind-control-plane}"
export SWA_SOCKET_PATH="${SWA_SOCKET_PATH:-/tmp/swa-agent/public/api.sock}"
# The SWA agent runs in the same namespace as the demo app (swa-probe).
export SWA_AGENT_NS="${SWA_AGENT_NS:-${PROBE_NS}}"

# SSH wrapper used by all demo scripts.
export SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=8 -i ${KIND_SSH_KEY}"
