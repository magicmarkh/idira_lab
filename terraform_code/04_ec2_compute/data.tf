# =====================================================================
# Conjur Data Sources - Shared credentials for EC2 resources
# =====================================================================
# These data sources retrieve secrets from Conjur that can be used
# across multiple EC2 instance types (connectors, targets, etc.)

# Domain join credentials
# ITERATION 1 (DC only): connectors are disabled, and on a from-scratch build these
# Conjur paths do not exist yet (the service account is created during the DC build).
# Re-enable in Iteration 2, count-gated on the domain_join_bootstrap toggle.
/*
data "conjur_secret" "domain_join_username" {
  name = var.conjur_domain_join_username_path
}

data "conjur_secret" "domain_join_password" {
  name = var.conjur_domain_join_password_path
}
*/

# Identity credentials
data "conjur_secret" "identity_client_id" {
  name = var.conjur_identity_client_id_path
}

data "conjur_secret" "identity_client_secret" {
  name = var.conjur_identity_client_secret_path
}

# AWS credentials (only fetched in API mode; IAM mode uses instance role)
data "conjur_secret" "aws_access_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_secret_key_path
}

# AWS PEM key (the EC2 key pair private key, vaulted in 02_security and synced to
# Conjur). Used by the DC promotion to decrypt the EC2-generated Administrator
# password via `aws ec2 get-password-data --priv-launch-key`, and by the
# connectors + kind_node modules (Iteration 2) for SSH.
data "conjur_secret" "aws_pem_key" {
  name = var.conjur_aws_pem_key_path
}

# SWA agent enrollment token (only fetched when enabling the SWA layer via a
# Conjur path; otherwise the token may be passed directly as a variable)
# ITERATION 1 (DC only): re-enable alongside the kind_node module.
/*
data "conjur_secret" "swa_agent_enrollment_token" {
  count = var.enable_swa_workloads && var.swa_agent_enrollment_token_path != "" ? 1 : 0
  name  = var.swa_agent_enrollment_token_path
}
*/

# =====================================================================
# Remote State Data Sources
# =====================================================================

# Data source to reference Idira connector pools outputs
# ITERATION 1 (DC only): only used by the connectors module. Re-enable in Iteration 2.
/*
data "terraform_remote_state" "idira_connector_pools" {
  backend = "local"

  config = {
    path = "../03_idira_config/connector_pools/terraform.tfstate"
  }
}
*/
