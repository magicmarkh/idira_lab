# =====================================================================
# Conjur Data Sources - Shared credentials for EC2 resources
# =====================================================================
# These data sources retrieve secrets from Conjur that are used by the
# providers (idsec identity) and by the credential vaulting in vault.tf.

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
# Conjur). Used to decrypt the EC2-generated Windows Administrator passwords via
# rsadecrypt(), and vaulted as-is as the Linux SSH root credential (see vault.tf).
data "conjur_secret" "aws_pem_key" {
  name = var.conjur_aws_pem_key_path
}

# SWA agent enrollment token (from the SWA / Secrets Manager tenant). Only
# fetched when the SWA layer is enabled AND a Conjur path is set; when the path
# is empty the raw var.swa_agent_enrollment_token is used instead (see kind.tf).
data "conjur_secret" "swa_agent_enrollment_token" {
  count = var.enable_swa_workloads && var.swa_agent_enrollment_token_path != "" ? 1 : 0
  name  = var.swa_agent_enrollment_token_path
}

# =====================================================================
# Remote State Data Sources
# =====================================================================

# Idira connector pools (from 03_idira_config/connector_pools). Retained for
# cross-layer wiring even though this raw-instance layer no longer consumes it.
data "terraform_remote_state" "idira_connector_pools" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/03_connector_pools.tfstate"
    region = "us-west-2"
  }
}
