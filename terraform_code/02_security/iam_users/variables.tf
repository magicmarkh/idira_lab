# ===========================
# IAM User Variables
# ===========================
variable "iam_username" {
  description = "IAM username for the automation user"
  type        = string
  # Example: "idira-lab-automation"
}

variable "iam_user_path" {
  description = "Path for the IAM user"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
  # Example: { Owner = "jane.doe@example.com", Team = "idira-lab", Environment = "lab" }
}
