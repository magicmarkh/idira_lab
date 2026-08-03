# =====================================================================
# Common
# =====================================================================
variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
  # Example: "jane.doe@example.com"
}

variable "region" {
  description = "AWS cloud region for the deployment"
  type        = string
  default     = "us-west-2"
}

variable "team_name" {
  description = "Cloud naming identifier (used as a prefix for resource names)"
  type        = string
  default     = "idira-lab"
}

# =====================================================================
# Conjur — Provider Connection
# =====================================================================
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

variable "conjur_authn_type" {
  description = "Conjur auth method: 'api' for API key (laptop), 'iam' for AWS IAM (EC2)"
  type        = string
  default     = "api"
  validation {
    condition     = contains(["api", "iam"], var.conjur_authn_type)
    error_message = "conjur_authn_type must be 'api' or 'iam'."
  }
}

# =====================================================================
# Conjur — Authentication Credentials
# Set the pair matching conjur_authn_type; leave the other pair empty.
# =====================================================================
# --- API key auth (conjur_authn_type = "api") ---
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
  # Example: "y0urapit0kenh3r3" 
}

# --- IAM role auth (conjur_authn_type = "iam") ---
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

# =====================================================================
# Conjur — Secret Paths
# =====================================================================
# --- AWS credentials (bootstrap the aws provider) ---
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

# --- Idira Identity service user (authenticates the idsec provider) ---
variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for the Idira Identity service-user client ID (used to authenticate the idsec provider)"
  type        = string
  # Example: "data/vault/aws/idira-lab-identity/username"
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for the Idira Identity service-user client secret (used to authenticate the idsec provider)"
  type        = string
  # Example: "data/vault/aws/idira-lab-identity/password"
}

# =====================================================================
# IAM Role (EC2 Terraform automation)
# =====================================================================
variable "ec2_tf_automation_role_name" {
  description = "Name of the IAM role (and instance profile) for EC2 Terraform automation"
  type        = string
  # Example: "InstanceProfileName"
}

# =====================================================================
# IAM User (automation user whose access key is vaulted)
# =====================================================================
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

variable "create_bootstrap_access_key" {
  description = <<-EOT
    Whether Terraform should create + vault the bootstrap AWS access key for
    the automation user. Set true ONLY for the initial lab build. After the
    first apply, run scripts/handoff_automation_key.sh and set this false so
    Idira/CPM fully owns rotation and later applies never recreate the key.
  EOT
  type        = bool
  default     = false
}

# =====================================================================
# Idira Vaulting
# =====================================================================
variable "automation_safe_name" {
  description = "Name of the Idira safe that will hold the automation user's AWS access key"
  type        = string
  # Example: "Idira-Safe-Name"
}

variable "automation_safe_members" {
  description = "Map of members to add to the automation safe with their permissions"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
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
  description = "Idira platform ID for the AWS access key account (must be a rotation-capable platform since Idira owns rotation)"
  type        = string
  default     = "YourPlatformName"
}

variable "automation_account_name" {
  description = "Account name in Idira Privilege Cloud for the automation AWS access key"
  type        = string
  default     = "idira-lab-automation"
}

# =====================================================================
# Idira Vaulting - AWS EC2 SSH key pair
# =====================================================================
variable "keypair_safe_name" {
  description = "Name of the Idira safe that will hold the AWS EC2 SSH private key"
  type        = string
  default     = "m-aws-keypair"
}

variable "keypair_safe_members" {
  description = "Map of members to add to the key-pair safe with their permissions (include a 'Conjur Sync' member to trigger Secrets Hub replication into Conjur)"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "keypair_account_platform_id" {
  description = "Idira platform ID for the EC2 private key account (an UNMANAGED platform - Idira stores but does not rotate the immutable key pair)"
  type        = string
  default     = "M-AWS-PEM-Unmanaged"
}

variable "keypair_account_name" {
  description = "Account name in Idira Privilege Cloud for the AWS EC2 private key"
  type        = string
  default     = "aws-keypair"
}
