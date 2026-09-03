# ===========================
# Identity service user (hard-coded credential)
# ===========================
variable "idsec_service_user" {
  type        = string
  description = "CyberArk Identity service-user (username) passed directly to the provider (insecure — prefer the Conjur-sourced 'secure/' example)"
}

variable "idsec_service_token" {
  type        = string
  description = "CyberArk Identity service-user secret/token passed directly to the provider (insecure — prefer the Conjur-sourced 'secure/' example)"
  sensitive   = true
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
