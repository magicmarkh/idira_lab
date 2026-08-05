# =====================================================================
# 03_idira_config/safes_and_accounts — input variables
#
# A REPEATABLE, tfvars-driven construct for CyberArk Privilege Cloud:
#   - create N safes (with members) via the shared safe module, and
#   - vault N accounts into those safes (or into pre-existing safes).
#
# You should not need to touch main.tf — describe everything in
# terraform.tfvars using the `safes` and `accounts` maps below.
# Defaults here are EXAMPLES; real values belong in terraform.tfvars.
# =====================================================================

# ---------------------------------------------------------------------
# SAFES — map keyed by an arbitrary local id (the "safe_key").
# The safe_key is what `accounts` reference to land in this safe, so keep
# it stable. Each safe reuses modules/idira/safe (safe + members).
# ---------------------------------------------------------------------
variable "safes" {
  description = "Safes to create, keyed by a stable local id used by accounts as safe_key"
  type = map(object({
    safe_name          = string
    description        = optional(string, "")
    retention_days     = optional(number, 7)
    auto_purge_enabled = optional(bool, false)
    olac_enabled       = optional(bool, false)
    location           = optional(string, "\\")
    # Members keyed by an arbitrary local id. member_type is IMMUTABLE in
    # CyberArk — to change it, rename the member's key (new resource).
    members = optional(map(object({
      member_name                = string
      member_type                = string # User | Group | Role
      search_in                  = optional(string)
      membership_expiration_date = optional(number)
      permission_set             = string # full | read_only | approver | manager | ...
    })), {})
  }))
  default = {}
}

# ---------------------------------------------------------------------
# ACCOUNTS — map keyed by an arbitrary local id. Each account is vaulted
# into a safe. Reference a safe created in THIS layer via `safe_key`, OR
# target a pre-existing safe by setting `safe_name` directly.
#
# `secret` is the literal credential vaulted onto the account. Leave it
# empty to create the account with no secret set (e.g. let CPM reconcile).
# The CPM may rotate the secret after creation — see the ignore_changes
# block in main.tf.
# ---------------------------------------------------------------------
variable "accounts" {
  description = "Accounts to vault, keyed by an arbitrary local id"
  type = map(object({
    # Target safe — set exactly one of these:
    safe_key  = optional(string, "") # references a key in var.safes
    safe_name = optional(string, "") # or an existing safe name

    platform_id = string
    username    = string
    address     = string
    name        = optional(string) # display name; defaults to "<username>-<address>"

    # Literal secret to vault (leave empty for no secret set).
    secret = optional(string, "")

    # Optional platform-specific extras
    platform_account_properties = optional(map(string), {})
    remote_machines             = optional(list(string), [])
  }))
  default = {}
}

# ---------------------------------------------------------------------
# Conjur provider
# ---------------------------------------------------------------------
variable "conjur_appliance_url" {
  description = "Conjur appliance URL (e.g. https://<subdomain>.secretsmgr.cyberark.cloud/api)"
  type        = string
  default     = ""
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login/host id for API-key auth (e.g. host/data/<your-tf-host>)"
  type        = string
  default     = ""
}

variable "conjur_api_key" {
  description = "Conjur API key for the login. Set in terraform.tfvars; keep out of VCS."
  type        = string
  sensitive   = true
  default     = ""
}

variable "conjur_authn_type" {
  description = "Conjur auth method: 'api' for API key (laptop), 'iam' for AWS IAM (EC2)"
  type        = string
  default     = "api"
  validation {
    condition     = contains(["api", "iam"], var.conjur_authn_type)
    error_message = "conjur_authn_type must be 'api' or 'iam'."
  }
}

variable "conjur_service_id" {
  description = "Conjur authn-iam service ID (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
}

variable "conjur_host_id" {
  description = "Conjur host identity for IAM auth (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------
# Conjur secret paths — consumed by provider.tf
# ---------------------------------------------------------------------
variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for the Idira Identity service-user (client id)"
  type        = string
  default     = ""
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for the Idira Identity service-user (client secret)"
  type        = string
  default     = ""
}

