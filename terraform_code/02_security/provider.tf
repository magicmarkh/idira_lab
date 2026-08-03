provider "aws" {
  region     = var.region
  access_key = var.conjur_authn_type == "api" ? data.conjur_secret.aws_access_key[0].value : null
  secret_key = var.conjur_authn_type == "api" ? data.conjur_secret.aws_secret_key[0].value : null
}

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    conjur = {
      source  = "cyberark/conjur"
      version = "~> 0.8.1"
    }
    idsec = {
      source  = "cyberark/idsec"
      version = "~> 0.7.1"
    }
  }
}

# =====================================================================
# Conjur Provider - For retrieving secrets
# =====================================================================
provider "conjur" {
  appliance_url = var.conjur_appliance_url
  account       = var.conjur_account
  authn_type    = var.conjur_authn_type == "iam" ? "aws" : "api"

  # API key auth (laptop) — null when using IAM
  login   = var.conjur_authn_type == "api" ? var.conjur_login : null
  api_key = var.conjur_authn_type == "api" ? var.conjur_api_key : null

  # IAM auth (EC2) — null when using API key
  service_id = var.conjur_authn_type == "iam" ? var.conjur_service_id : null
  host_id    = var.conjur_authn_type == "iam" ? var.conjur_host_id : null
}

# =====================================================================
# Idira Identity Security (IDSec) Provider
# Authenticates as an Identity service user whose credentials are
# retrieved from Conjur. Used to create the safe and vault the AWS key.
# =====================================================================
data "conjur_secret" "identity_client_id" {
  name = var.conjur_identity_client_id_path
}

data "conjur_secret" "identity_client_secret" {
  name = var.conjur_identity_client_secret_path
}

provider "idsec" {
  auth_method   = "identity_service_user"
  service_user  = data.conjur_secret.identity_client_id.value
  service_token = data.conjur_secret.identity_client_secret.value
}
