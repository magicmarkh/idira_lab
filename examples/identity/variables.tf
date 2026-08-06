# ===========================
# Conjur Variables
# ===========================
variable "conjur_appliance_url" {
  type        = string
  description = "conjur api url"
}
variable "conjur_account" {
  type        = string
  description = "conjur account name"
}
variable "conjur_api_key" {
  type        = string
  description = "conjur api key"
  sensitive   = true
  default     = ""
}
variable "conjur_login" {
  type        = string
  description = "conjur login name"
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

# ===========================
# Identity Role Variables
# ===========================
variable "role_name" {
  type        = string
  description = "Name of the identity role"
}

variable "role_description" {
  type        = string
  description = "Description of the identity role"
  default     = ""
}

# ===========================
# Identity User Variables
# ===========================
variable "users" {
  type = map(object({
    username      = string
    display_name  = string
    email         = string
    mobile_number = string
  }))
  description = "Map of users to create and add to the role"
}