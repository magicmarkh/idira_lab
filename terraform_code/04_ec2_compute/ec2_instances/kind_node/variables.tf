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

variable "swa_agent_chart_src" {
  description = "Absolute path ON THE CONTROL HOST (the machine running terraform) to the SWA agent chart .tgz. Ansible copies it to the node, then helm installs from the copy. Takes precedence over swa_agent_chart_local_path and repo mode. Keeps the .tgz off the node and out of the repo."
  type        = string
  default     = ""
}

variable "swa_agent_chart_local_path" {
  description = "Absolute path ON THE KIND NODE to a manually-uploaded SWA agent chart .tgz. Used only when swa_agent_chart_src is empty. When set, helm installs from this file and the repo_url/chart/version below are ignored."
  type        = string
  default     = ""
}

variable "swa_agent_token_set_key" {
  description = "Helm value key the chart expects for the enrollment token (helm --set <key>=<token>), e.g. 'enrollmentToken' or 'agent.enrollmentToken'."
  type        = string
  default     = "enrollmentToken"
}

variable "swa_agent_helm_repo_url" {
  description = "Helm chart repository URL for the SWA agent (repo mode only; ignored when swa_agent_chart_local_path is set)"
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

# ---------------------------------------------------------------------
# fetch-secret demo Job — Secrets Manager tenant params
#
# These render into the fetch-secret Job manifest (applied later by the demo
# scripts). They MUST match the Secrets Manager / Conjur side created by
# _future_idira_config/secrets_manager_swa/apply_swa_policy.sh.
# ---------------------------------------------------------------------
variable "swa_sm_subdomain" {
  description = "Secrets Manager tenant subdomain (e.g. 'ingen' from ingen.secretsmgr.cyberark.cloud)"
  type        = string
  default     = ""
}

variable "swa_sm_jwt_service_id" {
  description = "authn-jwt service ID configured in Secrets Manager for SWA"
  type        = string
  default     = "secureWorkloadAccess"
}

variable "swa_sm_password_var" {
  description = "Conjur variable path the fetch-secret Job reads (password)"
  type        = string
  default     = ""
}

variable "swa_sm_username_var" {
  description = "Conjur variable path the fetch-secret Job reads (username, optional)"
  type        = string
  default     = ""
}
