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
