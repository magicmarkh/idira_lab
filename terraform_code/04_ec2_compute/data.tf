# =====================================================================
# Conjur Data Sources - Shared credentials for EC2 resources
# =====================================================================
# These data sources retrieve secrets from Conjur that can be used
# across multiple EC2 instance types (connectors, targets, etc.)

# Domain join credentials (Iteration 2). The svc-domain-joiner account is created
# and vaulted during the DC build, so these Conjur paths exist by the time the
# connector module consumes them.
data "conjur_secret" "domain_join_username" {
  name = var.conjur_domain_join_username_path
}

data "conjur_secret" "domain_join_password" {
  name = var.conjur_domain_join_password_path
}

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

# Data source to reference Idira connector pools outputs (Iteration 2). The pool is
# created in 03_idira_config/connector_pools and consumed by the connector module.
data "terraform_remote_state" "idira_connector_pools" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/03_connector_pools.tfstate"
    region = "us-west-2"
  }
}
