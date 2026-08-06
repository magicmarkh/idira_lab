# ===========================
# General Configuration
# ===========================
variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
}

variable "region" {
  description = "AWS cloud region for the deployment"
  type        = string
  default     = "us-west-2"
}

variable "team_name" {
  description = "Cloud naming identifier"
  type        = string
  default     = "mh-west"
}

variable "iScheduler" {
  description = "iScheduler tag for automated shutdown"
  type        = string
  default     = "US_W_office"
}

# ===========================
# Connector Scaling Configuration
# ===========================
variable "connector_count" {
  description = "How many SIA connectors to deploy. Set this number and apply — that many EC2 hosts are created and registered as connectors."
  type        = number
  default     = 2

  validation {
    condition     = var.connector_count >= 0 && var.connector_count <= 25
    error_message = "connector_count must be between 0 and 25 for this demo."
  }
}

variable "hostname_prefix" {
  description = "Hostname prefix for each connector host; a 1-based index is appended (e.g. sia-connector-1)"
  type        = string
  default     = "sia-connector"
}

variable "instance_type" {
  description = "EC2 instance type for each connector host"
  type        = string
  default     = "t3a.small"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GiB) for each connector host"
  type        = number
  default     = 20
}

# ===========================
# SIA Connector Configuration
# ===========================
variable "connector_type" {
  description = "Platform the connector runs on (ON-PREMISE, AWS, AZURE, GCP)"
  type        = string
  default     = "ON-PREMISE"

  validation {
    condition     = contains(["ON-PREMISE", "AWS", "AZURE", "GCP"], var.connector_type)
    error_message = "connector_type must be one of ON-PREMISE, AWS, AZURE, GCP."
  }
}

variable "connector_os" {
  description = "Operating system of the connector host (linux, windows)"
  type        = string
  default     = "linux"

  validation {
    condition     = contains(["linux", "windows"], var.connector_os)
    error_message = "connector_os must be 'linux' or 'windows'."
  }
}

variable "connector_username" {
  description = "SSH user the idsec provider uses to install the connector on each host"
  type        = string
  default     = "ec2-user"
}

# ===========================
# Remote State Configuration
#   key_name is sourced from the 02_security remote state (see main.tf), so it
#   is intentionally not a variable here.
# ===========================
variable "state_bucket" {
  description = "S3 bucket holding the shared Terraform remote state (created by 01_foundation)"
  type        = string
  default     = "mh-tf-west-lab"
}

variable "state_region" {
  description = "AWS region for the S3 state bucket"
  type        = string
  default     = "us-west-2"
}

variable "foundation_state_key" {
  description = "S3 key for the 01_foundation layer state"
  type        = string
  default     = "state/01_foundation.tfstate"
}

variable "security_state_key" {
  description = "S3 key for the 02_security layer state (source of the EC2 key pair name)"
  type        = string
  default     = "state/02_security.tfstate"
}

variable "connector_pools_state_key" {
  description = "S3 key for the 03_idira_config/connector_pools layer state (source of the connector pool ID)"
  type        = string
  default     = "state/03_connector_pools.tfstate"
}

# ===========================
# Conjur Configuration
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
  default     = "data/your/conjur/path"
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for Identity client secret"
  type        = string
  default     = "data/your/conjur/path"
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for AWS Access Key ID"
  type        = string
  default     = "data/your/conjur/path"
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for AWS Secret Access Key"
  type        = string
  default     = "data/your/conjur/path"
}

variable "conjur_aws_pem_key_path" {
  description = "Conjur secret path for AWS PEM key for SSH access"
  type        = string
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
