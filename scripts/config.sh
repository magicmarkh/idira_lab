#!/bin/bash
# Shared configuration for tfvars and backend.tf management scripts

# S3 Configuration
export TFVARS_S3_BUCKET="mh-tf-west-lab"
export TFVARS_S3_REGION="us-west-2"
export TFVARS_S3_PREFIX="tfvars-config"

# Repository root (auto-detected)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# File patterns to manage
export TFVARS_FILENAME="terraform.tfvars"
export BACKEND_FILENAME="backend.tf"

# Sensitive field patterns (cleared before S3 upload, populated by set_secrets.sh)
SENSITIVE_FIELDS=("conjur_login" "conjur_api_key" "conjur_service_id" "conjur_host_id")

# Terraform code directories to process
TERRAFORM_CODE_DIRS=(
    "01_foundation"
    "02_security"
    "03_idira_config/connector_pools"
    "04_ec2_compute"
    "05_rds_databases"
    "06_aws_cce_config"
    "98_dev"
    "99_demo/windows_target"
    "99_demo/linux_target"
    # Deferred idira_config sub-states (users, accounts/*, sia_settings,
    # secrets_manager_swa) moved to terraform_code/_future_idira_config/ —
    # re-add here when you're ready to deploy them.
)

# Example directories to process
EXAMPLE_DIRS=(
    "privilege_cloud"
    "identity"
    "access_policy/csp_console/aws_iam"
    "access_policy/csp_console/aws_idc"
    "access_policy/csp_console/azure"
    "access_policy/csp_console/entra"
    "access_policy/csp_console/gcp"
)

# Colors for output (optional, for better UX)
export COLOR_GREEN='\033[0;32m'
export COLOR_RED='\033[0;31m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_RESET='\033[0m'
