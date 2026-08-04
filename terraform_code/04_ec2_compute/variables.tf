# =====================================================================
# 04_ec2_compute — input variables
#
# Iteration 1 scope: Domain Controller only. The variables consumed by the
# active DC build + providers are declared in the "ACTIVE" sections below.
# Variables for modules that are commented out in main.tf / data.tf
# (connectors, targets, kind node, SWA, Conjur-backed domain-join) are
# preserved in the FUTURE ITERATIONS block at the bottom — uncomment each
# alongside the module you re-enable.
#
# Real values belong in terraform.tfvars. Defaults here are EXAMPLES only.
# =====================================================================

# ---------------------------------------------------------------------
# Core / naming (ACTIVE)
# ---------------------------------------------------------------------
variable "region" {
  description = "AWS region for the deployment (e.g. us-east-2)"
  type        = string
  default     = "us-east-2"
}

variable "team_name" {
  description = "Cloud naming identifier / resource prefix (e.g. us-region-env)"
  type        = string
  default     = "us-region-env"
}

variable "asset_owner_name" {
  description = "Contact the cloud team can reach with questions (e.g. jane.doe@example.com)"
  type        = string
}

variable "iScheduler" {
  description = "Nightly shutdown schedule tag for the instance"
  type        = string
  default     = "US_W_office"
}

# ---------------------------------------------------------------------
# AMIs (ACTIVE) — null falls back to the latest matching AMI data source
# ---------------------------------------------------------------------
variable "amzn_windows_server_ami_id" {
  description = "Windows Server AMI id; null = latest Windows Server 2022"
  type        = string
  default     = null
}

variable "amzn_linux_ami_id" {
  description = "Amazon Linux AMI id; null = latest Amazon Linux 2023"
  type        = string
  default     = null
}

# ---------------------------------------------------------------------
# Domain Controller (ACTIVE)
# ---------------------------------------------------------------------
variable "dc1_private_ip" {
  description = "Private IP of the domain controller (e.g. 192.168.20.10)"
  type        = string
}

variable "domain_name" {
  description = "AD forest/domain FQDN to build and join (e.g. example.local)"
  type        = string
}

variable "domain_netbios" {
  description = "NetBIOS name of the AD domain (e.g. EXAMPLELAB)"
  type        = string
  default     = "EXAMPLELAB"
}

variable "domain_join_username_bootstrap" {
  description = "sAMAccountName for the domain-join service account created in AD during the DC build"
  type        = string
  default     = "svc-domain-joiner"
}

# ---------------------------------------------------------------------
# Conjur provider (ACTIVE)
# ---------------------------------------------------------------------
variable "conjur_appliance_url" {
  description = "Conjur appliance URL (e.g. https://<subdomain>.secretsmgr.cyberark.cloud/api)"
  type        = string
  default     = ""
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login/host id for API-key auth (e.g. host/data/<your-tf-host>)"
  type        = string
  default     = ""
}

variable "conjur_api_key" {
  description = "Conjur API key for the login. Set in terraform.tfvars; keep out of VCS."
  type        = string
  sensitive   = true
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

# ---------------------------------------------------------------------
# Conjur secret paths (ACTIVE) — consumed by data.tf / providers
# ---------------------------------------------------------------------
variable "conjur_identity_client_id_path" {
  description = "Conjur secret path for the Idira Identity service-user (client id)"
  type        = string
  default     = ""
}

variable "conjur_identity_client_secret_path" {
  description = "Conjur secret path for the Idira Identity service-user (client secret)"
  type        = string
  default     = ""
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for the AWS Access Key ID (api authn mode)"
  type        = string
  default     = ""
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for the AWS Secret Access Key (api authn mode)"
  type        = string
  default     = ""
}

# EC2 key pair private key (PEM), vaulted in 02_security and synced to Conjur.
# Iteration 1 (DC): used to decrypt the EC2-generated Administrator password.
# Iteration 2/3: reused for SSH into connectors / kind node.
variable "conjur_aws_pem_key_path" {
  description = "Conjur secret path for the AWS EC2 key pair private key (PEM)"
  type        = string
  default     = ""
}

# =====================================================================
# Idira vaulting — DC privileged accounts (Domain Admin, DSRM, svc-domain-joiner)
# Passed through to the dc module; see ec2_instances/dc/dc_secrets_vault.tf.
# =====================================================================
variable "dc_secrets_safe_name" {
  description = "Name of the Idira safe that holds the DC's privileged accounts"
  type        = string
}

variable "dc_secrets_safe_members" {
  description = "Map of members to add to the DC-secrets safe (include a 'Conjur Sync' member to trigger Secrets Hub replication into Conjur)"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "service_accounts_safe_name" {
  description = "Name of the Idira safe that holds domain service accounts (svc-domain-joiner, etc.)"
  type        = string
}

variable "service_accounts_safe_members" {
  description = "Map of members to add to the service-accounts safe (include a 'Conjur Sync' member to trigger Secrets Hub replication into Conjur)"
  type = map(object({
    member_name                = string
    member_type                = string
    search_in                  = optional(string)
    membership_expiration_date = optional(number)
    permission_set             = string
  }))
  default = {}
}

variable "domain_admin_platform_id" {
  description = "Idira platform ID for the Domain Administrator account (managed Windows-Domain platform)"
  type        = string
}

variable "domain_admin_account_name" {
  description = "Account name in Idira Privilege Cloud for the Domain Administrator"
  type        = string
  default     = "dc-domain-administrator"
}

variable "dsrm_platform_id" {
  description = "Idira platform ID for the DSRM (safe-mode) recovery password"
  type        = string
}

variable "dsrm_account_name" {
  description = "Account name in Idira Privilege Cloud for the DSRM recovery password"
  type        = string
  default     = "dc-dsrm-recovery"
}

variable "domain_join_platform_id" {
  description = "Idira platform ID for the domain-join service account (managed Windows-Domain platform)"
  type        = string
}

variable "domain_join_account_name" {
  description = "Account name in Idira Privilege Cloud for the domain-join service account"
  type        = string
  default     = "dc-svc-domain-joiner"
}

# =====================================================================
# FUTURE ITERATIONS
# Variables for modules currently commented out in main.tf / data.tf.
# Uncomment each block when you re-enable the matching module.
#   - Iteration 2: CyberArk connectors + Conjur-backed domain-join creds
#   - Iteration 3: targets + kind node (+ SWA layer)
# =====================================================================
# ---- Iteration 2: CyberArk connectors --------------------------------
variable "connector_1_private_ip" {
  description = "private ip of connector 1 (e.g. 192.168.20.20)"
  type        = string
}

variable "windows_connector_hostname" {
  description = "Hostname for the Windows connector instance"
  type        = string
  default     = "us-region-env-connector-1"
}

variable "sia_aws_connector_1_private_ip" {
  description = "private ip of sia aws connector 1 (e.g. 192.168.20.25)"
  type        = string
}

variable "linux_connector_count" {
  description = "Number of Linux SIA connectors to deploy"
  type        = number
  default     = 1
}

variable "linux_connector_hostname_prefix" {
  description = "Hostname prefix for Linux connectors (appends -1, -2, ...)"
  type        = string
  default     = "us-region-env-sia-aws-connector"
}

variable "linux_connector_name_prefix" {
  description = "Name tag prefix for Linux connectors"
  type        = string
  default     = "linux-sia-connector"
}

# ---- Iteration 2: Conjur-backed domain-join creds --------------------
variable "conjur_domain_join_username_path" {
  description = "Conjur secret path for the domain-join username"
  type        = string
  default     = ""
}

variable "conjur_domain_join_password_path" {
  description = "Conjur secret path for the domain-join password"
  type        = string
  default     = ""
}

# (conjur_aws_pem_key_path is declared above, outside this block — the DC uses it
#  in Iteration 1 to decrypt the EC2-generated Administrator password.)

# ---- Iteration 2: connector domain-join (SSM) + local-admin vaulting -
variable "domain_ou_path" {
  description = "Optional AD OU path for the connector computer object (e.g. OU=Servers,DC=example,DC=local)"
  type        = string
  default     = ""
}

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

/*
# ---- Iteration 3: targets --------------------------------------------
variable "linux_target_1_private_ip" {
  description = "private ip of linux target 1 (e.g. 192.168.20.40)"
  type        = string
}

variable "windows_target_1_private_ip" {
  description = "private ip of windows target 1 (e.g. 192.168.20.45)"
  type        = string
}

variable "identity_tenant_id" {
  description = "Idira tenant id. Example: 'https://abc123.id.cyberark.cloud' -> abc123"
  type        = string
}

variable "platform_tenant_name" {
  description = "Idira tenant name. Example: 'https://acme.cyberark.cloud' -> acme"
  type        = string
}

variable "workspace_type" {
  description = "CSP identifier. AWS, Azure, or GCP"
  type        = string
  default     = "AWS"
}

variable "linux_target_1_hostname" {
  description = "name of the linux target demo system"
  type        = string
}

# ---- Iteration 3: kind node + SWA layer ------------------------------
variable "kind_node_private_ip" {
  description = "private ip of the Kind Kubernetes node (e.g. 192.168.20.50)"
  type        = string
}

variable "kind_node_hostname" {
  description = "Hostname for the Kind Kubernetes node instance"
  type        = string
  default     = "us-region-env-kind-1"
}

variable "enable_swa_workloads" {
  description = "Deploy the SWA agent + swa-probe/fetch-secret onto the kind node after the cluster is up"
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

variable "swa_agent_enrollment_token_path" {
  description = "Conjur secret path holding the SWA agent enrollment token"
  type        = string
  default     = ""
}

variable "swa_agent_enrollment_token" {
  description = "SWA agent enrollment token passed directly (used only when the path is empty)"
  type        = string
  default     = ""
  sensitive   = true
}
*/
