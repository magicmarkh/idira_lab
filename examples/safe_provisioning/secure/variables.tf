# ===========================
# Conjur Variables — AWS IAM (EC2) authentication
# ===========================
variable "conjur_appliance_url" {
  type        = string
  description = "conjur api url"
}
variable "conjur_account" {
  type        = string
  description = "conjur account name"
}

variable "conjur_authenticator_name" {
  description = <<-EOT
    Name of the Conjur authn-iam authenticator ONLY (e.g. "corp-aws"). This is the
    last path segment, NOT the full web service ID the Conjur GUI shows. The GUI
    displays the object as "conjur/authn-iam/corp-aws"; the provider builds the URL
    as "authn-iam/<name>/...", so pasting the full path double-nests it and Conjur
    returns 404. Use "corp-aws", not "conjur/authn-iam/corp-aws".
  EOT
  type        = string
  validation {
    condition     = length(regexall("/", var.conjur_authenticator_name)) == 0
    error_message = "conjur_authenticator_name must be the authenticator name only (e.g. 'corp-aws'), not the full 'conjur/authn-iam/corp-aws' path shown in the GUI."
  }
}

variable "conjur_host_id" {
  description = "Conjur host identity registered for authn-iam (e.g. host/data/<branch>/<host>)"
  type        = string
}

# ===========================
# Conjur secret paths — vaulted Identity service user
# ===========================
variable "conjur_identity_user_path" {
  type        = string
  description = "Conjur secret path for the Identity service-user (username)"
}

variable "conjur_identity_secret_path" {
  type        = string
  description = "Conjur secret path for the Identity service-user (secret/token)"
}

# ===========================
# Privilege Cloud Safe
# ===========================
variable "safe_name" {
  type        = string
  description = "Name of the Privilege Cloud safe"
}

variable "safe_description" {
  type        = string
  description = "Description of the safe"
  default     = ""
}

variable "number_of_days_retention" {
  type        = number
  description = "Number of days to retain safe data"
  default     = 7
}

variable "safe_admin_member" {
  type        = string
  description = "User granted full (admin) permissions on the safe"
  default     = "mark.hurter@ingen.lab"
}
