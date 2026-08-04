variable "vpc_id" {}
variable "private_subnet_id" {}
variable "team_name" {}
variable "asset_owner_name" {}
variable "windows_ami_id" {
  description = "ami id for Windows Server - passed from parent module"
  type        = string
}
variable "iScheduler" {}
variable "security_group_ids" {}
variable "key_name" {}
variable "private_ip" {}
variable "windows_instance_type" {
  description = "instance type to be deployed"
  type        = string
  default     = "t3a.large"
}

variable "iam_instance_profile" {
  description = "Instance profile attached to the DC (retains break-glass SSM access; not used for the Ansible connection)"
  type        = string
}

variable "domain_name" {
  description = "AD forest/domain FQDN to promote (e.g. murphyslab.local)"
  type        = string
}

variable "domain_netbios" {
  description = "NetBIOS name of the AD domain (e.g. MURPHYSLAB)"
  type        = string
  default     = "YourNetBiosName"
}

variable "service_account_name" {
  description = "sAMAccountName for the domain-join service account created in AD during the build"
  type        = string
  default     = "svc-domain-joiner"
}

# EC2 key pair private key (PEM), sourced from Conjur by the root module. Used by
# Terraform (rsadecrypt) to decrypt the EC2-generated Administrator password blob.
variable "private_key_pem" {
  description = "EC2 key pair private key (PEM) used to decrypt the EC2-generated Administrator password"
  type        = string
  default     = ""
  sensitive   = true
}

# =====================================================================
# Idira vaulting — DC privileged accounts (Domain Admin, DSRM, svc-domain-joiner)
# =====================================================================
variable "dc_secrets_safe_name" {
  description = "Name of the Idira safe that holds the DC's privileged accounts"
  type        = string
}

variable "dc_secrets_safe_members" {
  description = "Map of members to add to the DC-secrets safe (include a 'Conjur Sync' member to trigger Secrets Hub replication into Conjur)"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "service_accounts_safe_name" {
  description = "Name of the Idira safe that holds domain service accounts (svc-domain-joiner, etc.)"
  type        = string
}

variable "service_accounts_safe_members" {
  description = "Map of members to add to the service-accounts safe (include a 'Conjur Sync' member to trigger Secrets Hub replication into Conjur)"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

# --- Domain Administrator (built-in Administrator -> Domain/Enterprise Admin) ---
variable "domain_admin_platform_id" {
  description = "Idira platform ID for the Domain Administrator account (managed Windows-Domain platform)"
  type        = string
}

variable "domain_admin_account_name" {
  description = "Account name in Idira Privilege Cloud for the Domain Administrator"
  type        = string
  default     = "dc-domain-administrator"
}

# --- DSRM / safe-mode recovery password (per-DC local secret) ---
variable "dsrm_platform_id" {
  description = "Idira platform ID for the DSRM (safe-mode) recovery password"
  type        = string
}

variable "dsrm_account_name" {
  description = "Account name in Idira Privilege Cloud for the DSRM recovery password"
  type        = string
  default     = "dc-dsrm-recovery"
}

# --- Domain-join service account (svc-domain-joiner) ---
variable "domain_join_platform_id" {
  description = "Idira platform ID for the domain-join service account (managed Windows-Domain platform)"
  type        = string
}

variable "domain_join_account_name" {
  description = "Account name in Idira Privilege Cloud for the domain-join service account"
  type        = string
  default     = "dc-svc-domain-joiner"
}