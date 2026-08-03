#!/bin/bash
set -euo pipefail

# =====================================================================
# Rotation handoff for the 02_security automation AWS access key
# =====================================================================
# Terraform creates the automation user's AWS access key ONCE so the
# secret can be captured and vaulted in Idira Privilege Cloud
# (see terraform_code/02_security/iam_users/main.tf). After the first
# successful apply, Idira owns rotation of that credential. The
# bootstrap access-key resource must therefore be removed from
# Terraform state so a later apply does not regenerate (and thereby
# invalidate) the CPM-rotated key.
#
# This script performs that one-time `terraform state rm` idempotently:
#   - if the resource is still tracked, it removes it and confirms
#   - if it is already gone, it exits cleanly with "nothing to do"
#
# `terraform state rm` does not call the provider, so no Conjur/Idira
# credentials are required to run this.
# =====================================================================

# Source shared configuration (REPO_ROOT, colors)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Resource to hand off to Idira-owned rotation
MODULE_DIR="${REPO_ROOT}/terraform_code/02_security"
RESOURCE_ADDRESS="module.create_automation_user.aws_iam_access_key.this"

main() {
    echo "=========================================="
    echo "Automation Access Key - Rotation Handoff"
    echo "=========================================="
    echo "Module:   terraform_code/02_security"
    echo "Resource: ${RESOURCE_ADDRESS}"
    echo "=========================================="
    echo ""

    # Ensure terraform is available
    if ! command -v terraform &> /dev/null; then
        echo -e "${COLOR_RED}ERROR: terraform not found in PATH.${COLOR_RESET}"
        exit 1
    fi

    # Ensure the module directory exists and has been initialized
    if [[ ! -d "${MODULE_DIR}" ]]; then
        echo -e "${COLOR_RED}ERROR: Module directory not found: ${MODULE_DIR}${COLOR_RESET}"
        exit 1
    fi

    cd "${MODULE_DIR}"

    # A state file must exist before there is anything to remove
    if ! terraform state list &> /dev/null; then
        echo -e "${COLOR_YELLOW}⊘ No Terraform state found for 02_security.${COLOR_RESET}"
        echo "  Nothing to do — run 'terraform apply' here first."
        exit 0
    fi

    # Idempotent check: is the bootstrap key still tracked in state?
    if terraform state list 2>/dev/null | grep -qxF "${RESOURCE_ADDRESS}"; then
        echo "Bootstrap access key is still tracked in state. Removing..."
        terraform state rm "${RESOURCE_ADDRESS}"
        echo ""
        echo -e "${COLOR_GREEN}✓ Removed ${RESOURCE_ADDRESS} from state.${COLOR_RESET}"
        echo "  Idira now fully owns rotation of this credential."
    else
        echo -e "${COLOR_YELLOW}⊘ ${RESOURCE_ADDRESS} is not in state.${COLOR_RESET}"
        echo "  Nothing to do — handoff has already been completed."
        exit 0
    fi

    echo ""
    echo "=========================================="
    echo "Done."
    echo "=========================================="
}

main "$@"
