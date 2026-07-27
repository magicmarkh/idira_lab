variable "linux_ami_id" {
  description = "AMI ID for Amazon Linux 2023"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Kind node"
  type        = string
  default     = "t3a.large"
}

variable "private_subnet_id" {
  description = "ID of the private subnet"
  type        = string
}

variable "linux_security_group_ids" {
  description = "Security group ID for SSH access"
  type        = string
}

variable "key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "kind_node_private_ip" {
  description = "Private IP address for the Kind node"
  type        = string
}

variable "kind_node_hostname" {
  description = "Hostname for the Kind node instance"
  type        = string
  default     = "us-ent-east-kind-1"
}

variable "team_name" {
  description = "Team name prefix for resource naming"
  type        = string
}

variable "asset_owner_name" {
  description = "Owner email for tagging"
  type        = string
}

variable "iScheduler" {
  description = "Scheduler tag for nightly shutdown"
  type        = string
}

variable "private_key_contents" {
  description = "SSH private key contents for Ansible provisioning"
  type        = string
  sensitive   = true
}

# =====================================================================
# SWA (Secure Workload Access) layer
# =====================================================================
variable "enable_swa_workloads" {
  description = "Deploy the SWA agent + swa-probe/fetch-secret after the kind cluster is up. Requires the SWA agent chart coordinates and enrollment token below."
  type        = bool
  default     = false
}

variable "swa_agent_helm_repo_url" {
  description = "Helm chart repository URL for the SWA agent (from your SWA tenant)"
  type        = string
  default     = ""
}

variable "swa_agent_chart" {
  description = "SWA agent Helm chart reference, e.g. cyberark-swa/swa-agent"
  type        = string
  default     = ""
}

variable "swa_agent_chart_version" {
  description = "Pinned SWA agent Helm chart version"
  type        = string
  default     = ""
}

variable "swa_agent_enrollment_token" {
  description = "SWA agent enrollment token (from your SWA tenant; source from Conjur, not plaintext tfvars)"
  type        = string
  default     = ""
  sensitive   = true
}
