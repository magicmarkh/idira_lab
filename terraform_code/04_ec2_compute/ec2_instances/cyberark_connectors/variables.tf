variable "vpc_id" {}
variable "private_subnet_id" {}
variable "team_name" {}
variable "asset_owner_name" {}
variable "windows_ami_id" {}
variable "iScheduler" {}
variable "domain_name" {}
variable "connector_pool_id" {
  description = "Idira connector manager pool ID"
  type        = string
}

variable "windows_security_group_ids" {
  description = "List of security group IDs to attach to the instances"
  type        = list(string)
}
variable "connector_1_private_ip" {}
variable "sia_aws_connector_1_private_ip" {}

variable "windows_connector_hostname" {
  description = "Hostname for the Windows connector instance"
  type        = string
  default     = "us-ent-east-connector-1"
}

variable "windows_instance_type" {
  description = "instance type to be deployed"
  type        = string
  default     = "t3a.medium"
}
variable "key_name" {
  description = "The name of the AWS key pair to use for the instance"
}

variable "iam_instance_profile" {
  description = "Instance profile attached to the connector (retains break-glass SSM access; the Ansible domain join connects directly over WinRM)"
  type        = string
}

# ===========================
# Linux Connector Variables
# ===========================
variable "linux_ami_id" {
  description = "AMI ID for Linux connector instance"
  type        = string
}

variable "linux_ami_id_instance_type" {
  description = "Instance type for Linux connector"
  type        = string
  default     = "t3a.medium"
}

variable "linux_security_group_ids" {
  description = "Security group ID for Linux connector"
  type        = string
}

variable "linux_connector_count" {
  description = "Number of Linux SIA connectors to deploy"
  type        = number
  default     = 1
}

variable "linux_connector_hostname_prefix" {
  description = "Hostname prefix for Linux connectors (will append -1, -2, -3, etc.)"
  type        = string
  default     = "us-ent-east-sia-aws-connector"
}

variable "linux_connector_name_prefix" {
  description = "Name tag prefix for Linux connectors"
  type        = string
  default     = "linux-sia-connector"
}

#variable "instance_profile_name" {
#  description = "IAM instance profile name for ASM access"
#  type        = string#
#}

variable "private_key_contents" {
  description = "Private key contents for SSH access (retrieved from Conjur)"
  type        = string
  sensitive   = true
}

# ===========================
# Conjur Secret Variables
# ===========================
variable "domain_join_username" {
  description = "Domain join username from Conjur"
  type        = string
  sensitive   = true
}

variable "domain_join_password" {
  description = "Domain join password from Conjur"
  type        = string
  sensitive   = true
}

# ===========================
# Domain Join (Improvement #2)
# ===========================
variable "domain_ou_path" {
  description = "Optional AD OU path for the connector computer object (e.g. OU=Servers,DC=example,DC=local)"
  type        = string
  default     = ""
}

# ===========================
# Local Administrator Vaulting (Improvement #1)
# ===========================
variable "connector_safe_name" {
  description = "Name of the Idira safe that holds the connector's local Administrator account"
  type        = string
}

variable "connector_safe_description" {
  description = "Description for the connector local-admin safe"
  type        = string
  default     = "Windows CyberArk Connector - Local Administrator Account"
}

variable "connector_safe_retention_days" {
  description = "Number of days of version retention on the connector safe"
  type        = number
  default     = 0
}

variable "connector_local_admin_platform_id" {
  description = "Idira platform ID for the connector's local Administrator account"
  type        = string
}
