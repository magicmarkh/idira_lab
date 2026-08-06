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

variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for Identity client ID"
  type        = string
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for Identity client secret"
  type        = string
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