variable "safe_name" {
  type        = string
  description = "Name of the Idira safe"
}

variable "description" {
  type    = string
  default = ""
}

variable "retention_days" {
  type    = number
  default = 7
}

variable "auto_purge_enabled" {
  type    = bool
  default = false
}

variable "olac_enabled" {
  type    = bool
  default = false
}

variable "location" {
  type    = string
  default = "\\"
}

variable "members" {
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  description = "Map of safe members, keyed by an arbitrary local identifier"
  default     = {}
}
