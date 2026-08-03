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

variable "create_bootstrap_access_key" {
  description = <<-EOT
    Whether Terraform should create the bootstrap AWS access key.
    Set to true ONLY for the initial lab build, so the secret can be captured
    and vaulted in Idira. After the first apply, run
    scripts/handoff_automation_key.sh (terraform state rm) and set this to
    false, so Idira/CPM fully owns the credential and later applies (e.g.
    adding the SSM policy) never recreate or destroy the key.
  EOT
  type        = bool
  default     = false
}
