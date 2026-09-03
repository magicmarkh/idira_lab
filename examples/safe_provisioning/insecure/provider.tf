terraform {
  required_version = ">= 1.3.0"
  required_providers {
    idsec = {
      source  = "cyberark/idsec"
      version = "~> 0.8.1"
    }
  }
}

# ===========================================================================
# INSECURE PATTERN
#
# The CyberArk Identity service-user credential (service_user + service_token)
# is hard-coded in terraform.tfvars and handed straight to the idsec provider.
# The long-lived secret lives in the config and in state — nothing is vaulted.
# The `secure/` sibling does the exact same thing but retrieves the same
# service-user credential from CyberArk Conjur at plan/apply time. Compare the
# two provider.tf files.
# ===========================================================================
provider "idsec" {
  auth_method   = "identity_service_user"
  service_user  = var.idsec_service_user
  service_token = var.idsec_service_token
}
