terraform {
  required_version = ">= 1.3.0"
  required_providers {
    idsec = {
      source  = "cyberark/idsec"
      version = "~> 0.8.1"
    }
    conjur = {
      source  = "cyberark/conjur"
      version = "~> 0.8.1"
    }
  }
}

# ===========================================================================
# SECURE PATTERN — Conjur AWS IAM (EC2) authentication
#
# No Identity service-user credential lives in the config. This must run ON an
# EC2 host whose instance profile is registered as a Conjur authn-iam host. The
# Conjur provider signs an STS GetCallerIdentity request with the instance-profile
# credentials to authenticate (authn_type = "aws"), the two data sources below
# read the vaulted Identity service-user (username + token), and only then is it
# handed to the idsec provider — which then creates the safe.
# Compare provider.tf here with the `insecure/` sibling.
# ===========================================================================
provider "conjur" {
  appliance_url = var.conjur_appliance_url
  account       = var.conjur_account

  # AWS IAM authentication (no login/api_key).
  authn_type = "aws"
  service_id = var.conjur_authenticator_name
  host_id    = var.conjur_host_id
}

data "conjur_secret" "identity_service_user" {
  name = var.conjur_identity_user_path
}

data "conjur_secret" "identity_service_token" {
  name = var.conjur_identity_secret_path
}

provider "idsec" {
  auth_method   = "identity_service_user"
  service_user  = data.conjur_secret.identity_service_user.value
  service_token = data.conjur_secret.identity_service_token.value
}
