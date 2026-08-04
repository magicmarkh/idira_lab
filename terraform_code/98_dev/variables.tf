# ===========================
# General Configuration
# ===========================
variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
}

variable "region" {
  description = "AWS cloud region for the deployment (must match 01_foundation)"
  type        = string
  default     = "us-west-2"
}

variable "team_name" {
  description = "Cloud naming identifier (prefix for the instance Name tag)"
  type        = string
  default     = "your-lab-name"
}

variable "iScheduler" {
  description = "iScheduler tag for automated shutdown"
  type        = string
  default     = "US_W_office"
}

# ===========================
# Instance Configuration
# ===========================
variable "hostname" {
  description = "Hostname for the dev instance"
  type        = string
  default     = "hostname"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.medium"
}

variable "private_ip" {
  description = "Static private IP within the foundation private subnet (192.168.20.0/24)"
  type        = string
  default     = "192.168.2.200"
}

variable "key_name" {
  description = "Optional EC2 key pair for break-glass access (SSM is the primary path). Set to \"\" to omit."
  type        = string
  default     = null
}

variable "ssm_transfer_bucket" {
  description = "S3 bucket the community.aws.aws_ssm connection plugin uses to stage files (reuses the state bucket)"
  type        = string
  default     = "bucket-name"
}

# ===========================
# Conjur Configuration
# ===========================
variable "conjur_appliance_url" {
  description = "URL of the Conjur appliance"
  type        = string
  default     = "https://subdomain.secretsmgr.cyberark.cloud/api"
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login name"
  type        = string
  default     = "host/data/your/conjur/workload/identity"
}

variable "conjur_api_key" {
  description = "Conjur API key for the specified login"
  type        = string
  sensitive   = true
  default     = ""
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for AWS Access Key ID"
  type        = string
  default     = "data/vault/your/key/path/username"
}

variable "conjur_aws_secret_key_path" {

  description = "Conjur secret path for AWS Secret Access Key"
  type        = string
  default     = "data/vault/your/key/path/password"
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

variable "conjur_service_id" {
  description = "Conjur authn-iam service ID (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
}

variable "conjur_host_id" {
  description = "Conjur host identity for IAM auth (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
}
