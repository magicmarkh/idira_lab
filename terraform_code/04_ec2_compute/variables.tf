# =====================================================================
# 04_ec2_compute — input variables
#
# Scope: deploy four RAW EC2 instances (DC, Windows connector, Windows
# target, Linux target) with no config automation, and vault each system's
# local credential into two CyberArk safes.
#
# Real values belong in terraform.tfvars. Defaults here are EXAMPLES only.
# =====================================================================

# ---------------------------------------------------------------------
# Core / naming
# ---------------------------------------------------------------------
variable "region" {
  description = "AWS region for the deployment (must match 01_foundation)"
  type        = string
  default     = "us-west-2"
}

variable "team_name" {
  description = "Cloud naming identifier / resource prefix (e.g. us-region-env)"
  type        = string
  default     = "us-region-env"
}

variable "asset_owner_name" {
  description = "Contact the cloud team can reach with questions (e.g. jane.doe@example.com)"
  type        = string
}

variable "iScheduler" {
  description = "Nightly shutdown schedule tag for the instances"
  type        = string
  default     = "US_W_office"
}

# ---------------------------------------------------------------------
# AMIs — null falls back to the latest matching AMI data source
# ---------------------------------------------------------------------
variable "amzn_windows_server_ami_id" {
  description = "Windows Server AMI id; null = latest Windows Server 2022"
  type        = string
  default     = null
}

variable "amzn_linux_ami_id" {
  description = "Amazon Linux AMI id; null = latest Amazon Linux 2023"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------
# Instances — IPs, hostnames, sizes
# ---------------------------------------------------------------------
variable "dc1_private_ip" {
  description = "Private IP of the domain controller (e.g. 192.168.20.10)"
  type        = string
}

variable "dc_hostname" {
  description = "Hostname / Name-tag suffix for the domain controller (<=15 chars)"
  type        = string
  default     = "dc1"
}

variable "dc_instance_type" {
  description = "EC2 instance type for the domain controller"
  type        = string
  default     = "t3a.large"
}

variable "connector_1_private_ip" {
  description = "Private IP of the Windows connector (e.g. 192.168.20.20)"
  type        = string
}

variable "windows_connector_hostname" {
  description = "Hostname / Name-tag suffix for the Windows connector (<=15 chars)"
  type        = string
  default     = "conn1"
}

variable "connector_instance_type" {
  description = "EC2 instance type for the Windows connector"
  type        = string
  default     = "t3a.large"
}

variable "windows_target_1_private_ip" {
  description = "Private IP of the Windows target (e.g. 192.168.20.45)"
  type        = string
}

variable "windows_target_hostname" {
  description = "Hostname / Name-tag suffix for the Windows target (<=15 chars)"
  type        = string
  default     = "wintgt1"
}

variable "windows_target_instance_type" {
  description = "EC2 instance type for the Windows target"
  type        = string
  default     = "t3a.medium"
}

variable "linux_target_1_private_ip" {
  description = "Private IP of the Linux target (e.g. 192.168.20.40)"
  type        = string
}

variable "linux_target_1_hostname" {
  description = "Hostname / Name-tag suffix for the Linux target"
  type        = string
  default     = "lintgt1"
}

variable "linux_target_instance_type" {
  description = "EC2 instance type for the Linux target"
  type        = string
  default     = "t3a.medium"
}

# ---------------------------------------------------------------------
# CyberArk vaulting — safes, platforms, members
# ---------------------------------------------------------------------
variable "win_local_admin_safe_name" {
  description = "Name of the safe holding the Windows local Administrator accounts"
  type        = string
  default     = "MH-Win-Local-Admin"
}

variable "win_local_admin_safe_retention_days" {
  description = "Version retention (days) on the Windows local-admin safe"
  type        = number
  default     = 7
}

variable "win_local_platform_id" {
  description = "Platform ID for the Windows local Administrator accounts (must exist in the tenant)"
  type        = string
  default     = "MH-Win-Local"
}

variable "win_local_admin_safe_members" {
  description = "Members to add to the Windows local-admin safe"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "linux_ssh_root_safe_name" {
  description = "Name of the safe holding the Linux SSH root key"
  type        = string
  default     = "MH-Linux-SSH-Root"
}

variable "linux_ssh_root_safe_retention_days" {
  description = "Version retention (days) on the Linux SSH-root safe"
  type        = number
  default     = 7
}

variable "lin_ssh_platform_id" {
  description = "Platform ID for the Linux SSH root account (SSH-key platform; must exist in the tenant)"
  type        = string
  default     = "MH-SSH-Root"
}

variable "linux_vault_username" {
  description = "Username stored on the Linux SSH-key account (AL2023's real login is ec2-user; MH-SSH-Root implies root)"
  type        = string
  default     = "root"
}

variable "linux_ssh_root_safe_members" {
  description = "Members to add to the Linux SSH-root safe"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
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

# ---------------------------------------------------------------------
# Conjur secret paths — consumed by data.tf / providers
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

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for the AWS Access Key ID (api authn mode)"
  type        = string
  default     = ""
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for the AWS Secret Access Key (api authn mode)"
  type        = string
  default     = ""
}

# EC2 key pair private key (PEM), vaulted in 02_security and synced to Conjur.
# Used to decrypt EC2-generated Windows Administrator passwords (rsadecrypt) and
# as the vaulted Linux SSH credential.
variable "conjur_aws_pem_key_path" {
  description = "Conjur secret path for the AWS EC2 key pair private key (PEM)"
  type        = string
  default     = ""
}
