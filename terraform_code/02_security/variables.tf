# ===========================
# Common Variables
# ===========================
variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
  # Example: "jane.doe@example.com"
}

variable "region" {
  description = "AWS cloud region for the deployment"
  type        = string
  default     = "us-east-2"
}

variable "team_name" {
  description = "Cloud naming identifier (used as a prefix for resource names)"
  type        = string
  default     = "idira-lab"
}

# ===========================
# IAM Role Variables
# ===========================
variable "ec2_tf_automation_role_name" {
  description = "Name of the IAM role (and instance profile) for EC2 Terraform automation"
  type        = string
  default     = "ec2-tf-automation-role"
}

# ===========================
# Conjur Variables
# ===========================
variable "conjur_appliance_url" {
  description = "URL of the Conjur appliance"
  type        = string
  default     = ""
  # Example: "https://<subdomain>.secretsmgr.cyberark.cloud/api"
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login name (host identity for API key auth)"
  type        = string
  default     = ""
  # Example: "host/data/aws/idira-lab-terraform"
}

variable "conjur_api_key" {
  description = "Conjur API key for the specified login"
  type        = string
  sensitive   = true
  default     = ""
  # Example: "2x8y1a3b4c5d6e7f8g9h0i1j2k3l4m5n" (do not commit real values)
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for AWS Access Key ID"
  type        = string
  default     = ""
  # Example: "data/aws/idira-lab/access_key_id"
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for AWS Secret Access Key"
  type        = string
  default     = ""
  # Example: "data/aws/idira-lab/secret_access_key"
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
  # Example: "prod"
}

variable "conjur_host_id" {
  description = "Conjur host identity for IAM auth (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
  # Example: "123456789012/idira-lab-ec2-role"
}

variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for the CyberArk Identity service-user client ID (used to authenticate the idsec provider)"
  type        = string
  # Example: "data/vault/aws/idira-lab-identity/username"
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for the CyberArk Identity service-user client secret (used to authenticate the idsec provider)"
  type        = string
  # Example: "data/vault/aws/idira-lab-identity/password"
}

# ===========================
# IAM User Variables
# ===========================
variable "automation_iam_username" {
  description = "IAM username for the automation user"
  type        = string
  default     = "idira-lab-automation"
}

variable "automation_iam_user_path" {
  description = "Path for the automation IAM user"
  type        = string
  default     = "/"
}

# ===========================
# CyberArk Vaulting Variables
# ===========================
variable "automation_safe_name" {
  description = "Name of the CyberArk safe that will hold the automation user's AWS access key"
  type        = string
  default     = "m-idira-lab-automation"
}

variable "automation_safe_members" {
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  description = "Map of members to add to the automation safe with their permissions"
  default     = {}
  # Example:
  # {
  #   conjur_sync = {
  #     member_name    = "Conjur Sync"
  #     member_type    = "User"
  #     search_in      = "System Component Users"
  #     permission_set = "read_only"
  #   }
  #   se_team = {
  #     member_name    = "SE Team"
  #     member_type    = "Group"
  #     search_in      = "CyberArk Cloud Directory"
  #     permission_set = "full"
  #   }
  # }
}

variable "automation_account_platform_id" {
  description = "CyberArk platform ID for the AWS access key account (must be a rotation-capable platform since CyberArk owns rotation)"
  type        = string
  default     = "M-AWS-Access-Keys"
}

variable "automation_account_name" {
  description = "Account name in CyberArk Privilege Cloud for the automation AWS access key"
  type        = string
  default     = "idira-lab-automation"
}
