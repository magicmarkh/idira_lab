# =====================================================================
# 03_idira_config/zsp_policies — input variables
#
# Zero Standing Privileges (ZSP) VM access policy for SIA. Grants RDP +
# SSH access to targets in the lab VPC using ephemeral users:
#   - SSH  -> connect as a fixed username (e.g. ec2-user)
#   - RDP  -> ephemeral local user placed in a local group (e.g. Administrators)
#
# The target VPC is read from 01_foundation's remote state, so you do not
# set a VPC id here. Fill in the principals (who gets access) in tfvars.
# =====================================================================

variable "region" {
  description = "AWS region the targets live in (used to scope the VM policy's AWS resource match)"
  type        = string
  default     = "us-west-2"
}

variable "target_account_ids" {
  description = "AWS account ID(s) owning the target VPC. Required for AWS-resource (VPC) targeting so SIA can resolve the VPC."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------
# Policy metadata
# ---------------------------------------------------------------------
variable "policy_name" {
  description = "Unique name for the ZSP VM access policy (1-200 chars)"
  type        = string
}

variable "policy_description" {
  description = "Short description of the policy (max 200 chars)"
  type        = string
  default     = ""
}

variable "policy_tags" {
  description = "Optional tags to help identify the policy (max 20)"
  type        = list(string)
  default     = []
}

variable "time_zone" {
  description = "Time zone identifier for the policy's access window (e.g. America/Los_Angeles)"
  type        = string
  default     = "GMT"
}

# ---------------------------------------------------------------------
# Principals — who is granted access.
#
# One object per identity. The identity `id` is resolved automatically
# from `username` via the idsec_identity_user data source (see main.tf) —
# you only fill in the username, the display `name`, and the `type`.
# Add as many entries as you need, just like the safe-membership list.
# ---------------------------------------------------------------------
variable "principals" {
  description = "Identities granted access. `username` resolves the id automatically; set `name` and `type` yourself."
  type = list(object({
    username              = string                                       # looked up to resolve the identity id
    name                  = optional(string)                             # display name on the policy (defaults to username)
    type                  = string                                       # USER | GROUP | ROLE
    source_directory_id   = optional(string)                             # required unless type = ROLE
    source_directory_name = optional(string, "CyberArk Cloud Directory") # required unless type = ROLE
  }))
  default = []
}

# ---------------------------------------------------------------------
# Connect-as behavior
# ---------------------------------------------------------------------
variable "ssh_username" {
  description = "Username used for SSH connections (the certificate/ephemeral user)"
  type        = string
  default     = "ec2-user"
}

variable "rdp_assign_groups" {
  description = "Local group(s) the RDP ephemeral user is placed into on the target"
  type        = list(string)
  default     = ["Administrators"]
}

variable "rdp_enable_reconnect" {
  description = "Allow the RDP ephemeral user to reconnect within the session"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------
# Access window / session conditions
# ---------------------------------------------------------------------
variable "access_window_days" {
  description = "Days the policy is usable (Sun=0 ... Sat=6)"
  type        = set(number)
  default     = [0, 1, 2, 3, 4, 5, 6]
}

variable "access_window_from_hour" {
  description = "Access window start time (HH:MM:SS)"
  type        = string
  default     = "06:00"
}

variable "access_window_to_hour" {
  description = "Access window end time (HH:MM:SS)"
  type        = string
  default     = "21:00"
}

variable "max_session_duration" {
  description = "Maximum length of a single session, in hours"
  type        = number
  default     = 4
}

variable "idle_time" {
  description = "Maximum idle time before the session ends, in minutes"
  type        = number
  default     = 15
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
