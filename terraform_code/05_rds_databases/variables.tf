variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
}

variable "region" {
  description = "AWS cloud region for the deployment"
  default     = "us-east-2"
  type        = string
}

variable "team_name" {
  description = "cloud naming identifier"
  default     = "us-ent-east"
  type        = string
}

variable "iScheduler" {
  description = "use if the system should be shutdown nightly"
  type        = string
  default     = "US_E_office"
}

# ---------------------------------------------------------------------
# MSSQL self-managed AD domain join
#
# The domain-join account is sourced from Conjur and bridged into AWS Secrets
# Manager (see data.tf / mssql_domain_secret.tf); RDS reads it from ASM. Set
# mssql_domain_join_enabled = false to deploy a standalone SQL Server Express.
# ---------------------------------------------------------------------
variable "mssql_domain_join_enabled" {
  description = "Join the RDS SQL Server to self-managed AD using the Conjur-sourced domain-join account. False = standalone."
  type        = bool
  default     = true
}

variable "mssql_domain_fqdn" {
  description = "Fully-qualified AD domain name for the MSSQL domain join (e.g. mh.local)"
  type        = string
  default     = "mh.local"
}

variable "mssql_domain_ou" {
  description = "Organizational Unit (OU) in AD where the RDS MSSQL computer object is created (must already exist)"
  type        = string
  default     = null
}

variable "conjur_domain_join_username_path" {
  description = "Conjur secret path for the AD domain-join account username"
  type        = string
  default     = "data/vault/MH-Service-Accounts/mh-svc-domainjoiner/username"
}

variable "conjur_domain_join_password_path" {
  description = "Conjur secret path for the AD domain-join account password"
  type        = string
  default     = "data/vault/MH-Service-Accounts/mh-svc-domainjoiner/password"
}

# ===========================
# Remote State Variables
# ===========================
variable "state_bucket" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "my-terraform-state-bucket"
}

variable "foundation_state_key" {
  description = "S3 key for foundation Terraform state"
  type        = string
  default     = "terraform/foundation.tfstate"
}

variable "state_region" {
  description = "AWS region for Terraform state bucket"
  type        = string
  default     = "us-east-1"
}

# ===========================
# Conjur Variables
# ===========================
variable "conjur_appliance_url" {
  description = "URL of the Conjur appliance"
  type        = string
  default     = "https://murphyslab.secretsmgr.cyberark.cloud/api"
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login name"
  type        = string
  default     = "host/data/murphys-tf"
}

variable "conjur_api_key" {
  description = "Conjur API key for the specified login"
  type        = string
  sensitive   = true
  default     = ""
}

# ---------------------------------------------------------------------
# Idira Identity service user (for the idsec provider that vaults DB creds)
# ---------------------------------------------------------------------
variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for the Idira Identity service-user (client id / username)"
  type        = string
  default     = ""
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for the Idira Identity service-user (client secret / password)"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------
# CyberArk vaulting of the RDS master credentials
# ---------------------------------------------------------------------
variable "db_safe_retention_days" {
  description = "Version retention (days) on the database credential safes"
  type        = number
  default     = 7
}

variable "postgresql_safe_name" {
  description = "Name of the safe holding the PostgreSQL master credential"
  type        = string
  default     = "MH-PostgreSQL"
}

variable "postgresql_platform_id" {
  description = "Platform ID for the PostgreSQL master account (must already exist in the tenant)"
  type        = string
  default     = "MH-PostgreSQL"
}

variable "postgresql_safe_members" {
  description = "Members to add to the PostgreSQL safe"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "mssql_safe_name" {
  description = "Name of the safe holding the MSSQL master credential"
  type        = string
  default     = "MH-MSSQL"
}

variable "mssql_platform_id" {
  description = "Platform ID for the MSSQL master account (must already exist in the tenant)"
  type        = string
  default     = "MH-MSSQL"
}

variable "mssql_safe_members" {
  description = "Members to add to the MSSQL safe"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for AWS Access Key ID"
  type        = string
  default     = ""
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for AWS Secret Access Key"
  type        = string
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

variable "conjur_authenticator_name" {
  description = <<-EOT
    Name of the Conjur authn-iam authenticator ONLY (e.g. "corp-aws"), required
    when conjur_authn_type = 'iam'. This is the last path segment, NOT the full
    web service ID the Conjur GUI shows. The GUI displays the object as
    "conjur/authn-iam/corp-aws"; the provider builds the URL as
    "authn-iam/<name>/...", so pasting the full path double-nests it and Conjur
    returns 404. Use "corp-aws", not "conjur/authn-iam/corp-aws".
  EOT
  type        = string
  default     = ""
  validation {
    condition     = length(regexall("/", var.conjur_authenticator_name)) == 0
    error_message = "conjur_authenticator_name must be the authenticator name only (e.g. 'corp-aws'), not the full 'conjur/authn-iam/corp-aws' path shown in the GUI."
  }
}

variable "conjur_host_id" {
  description = "Conjur host identity for IAM auth (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
}
