data "aws_caller_identity" "current" {}

# =====================================================================
# DATA SOURCE - Latest Amazon Linux AMI
# =====================================================================
data "aws_ami" "amazon_linux_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_ami" "windows_2022_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# =====================================================================
# REMOTE STATE - Foundation Layer
# =====================================================================
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/01_foundation.tfstate"
    region = "us-west-2"
  }
}

# =====================================================================
# REMOTE STATE - Security Layer
# =====================================================================
data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/02_security.tfstate"
    region = "us-west-2"
  }
}

# =====================================================================
# LOCALS
# =====================================================================
locals {
  # Use latest Amazon Linux AMI from data source if variable is null
  linux_ami_id = var.amzn_linux_ami_id != null ? var.amzn_linux_ami_id : data.aws_ami.amazon_linux_latest.id

  # Use latest Windows Server 2022 AMI from data source if variable is null
  windows_ami_id = var.amzn_windows_server_ami_id != null ? var.amzn_windows_server_ami_id : data.aws_ami.windows_2022_latest.id
}

# =====================================================================
# KEY PAIR
# =====================================================================
# The SSH key pair is now generated and vaulted in 02_security (so it
# exists before any compute). We consume the key NAME via remote state;
# the private key lives in Conjur (data.conjur_secret.aws_pem_key).

# =====================================================================
# EC2 INSTANCES
# =====================================================================
module "dc" {
  source           = "./ec2_instances/dc"
  vpc_id           = data.terraform_remote_state.foundation.outputs.vpc_id
  team_name        = var.team_name
  asset_owner_name = var.asset_owner_name
  windows_ami_id   = local.windows_ami_id
  key_name         = data.terraform_remote_state.security.outputs.key_name
  iScheduler       = var.iScheduler
  security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.domain_controller_sg_id,
    # WinRM SG: the in-VPC Terraform host reaches the DC directly on 5985 to run
    # the Ansible promotion (winrm_internal_flat allows 5985 from internal subnets).
    data.terraform_remote_state.foundation.outputs.winrm_internal_flat_sg_id,
  ]
  private_ip        = var.dc1_private_ip
  private_subnet_id = data.terraform_remote_state.foundation.outputs.private_subnet_id

  # Instance profile attached to the DC (retains break-glass SSM access; the Ansible
  # promotion connects directly over WinRM, not via SSM).
  iam_instance_profile = data.terraform_remote_state.security.outputs.ec2_tf_automation_instance_profile_name

  # Domain build inputs (consumed by the Ansible domain_controller role).
  domain_name          = var.domain_name
  domain_netbios       = var.domain_netbios
  service_account_name = var.domain_join_username_bootstrap

  # EC2 key pair private key (from Conjur). Terraform decrypts the EC2-generated
  # Administrator password with it (rsadecrypt) to feed both promotion and vaulting.
  private_key_pem = data.conjur_secret.aws_pem_key.value

  # Idira vaulting of the DC's privileged accounts (Domain Admin, DSRM, domain-join),
  # synced to Conjur. CPM-managed platforms; see ec2_instances/dc/dc_secrets_vault.tf.
  dc_secrets_safe_name    = var.dc_secrets_safe_name
  dc_secrets_safe_members = var.dc_secrets_safe_members

  # Separate safe for domain service accounts (svc-domain-joiner) consumed by the
  # connector's Ansible domain join.
  service_accounts_safe_name    = var.service_accounts_safe_name
  service_accounts_safe_members = var.service_accounts_safe_members

  domain_admin_platform_id  = var.domain_admin_platform_id
  domain_admin_account_name = var.domain_admin_account_name
  dsrm_platform_id          = var.dsrm_platform_id
  dsrm_account_name         = var.dsrm_account_name
  domain_join_platform_id   = var.domain_join_platform_id
  domain_join_account_name  = var.domain_join_account_name
}

module "cyberark_connectors" {
  source = "./ec2_instances/cyberark_connectors"
  # The connector joins the domain the DC builds and reads domain-join creds the DC
  # vaults into Conjur, so the entire DC module (promotion + AD content + warm-up)
  # must complete before the connector starts.
  depends_on = [module.dc]

  vpc_id           = data.terraform_remote_state.foundation.outputs.vpc_id
  team_name        = var.team_name
  asset_owner_name = var.asset_owner_name
  windows_ami_id   = local.windows_ami_id
  key_name         = data.terraform_remote_state.security.outputs.key_name
  iScheduler       = var.iScheduler
  windows_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.https_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.sia_windows_target_sg_id,
    data.terraform_remote_state.foundation.outputs.winrm_internal_flat_sg_id
  ]
  private_subnet_id              = data.terraform_remote_state.foundation.outputs.private_subnet_id
  connector_1_private_ip         = var.connector_1_private_ip
  sia_aws_connector_1_private_ip = var.sia_aws_connector_1_private_ip
  windows_connector_hostname     = var.windows_connector_hostname

  # Instance profile attached to the connector (retains break-glass SSM access; the
  # Ansible domain join connects directly over WinRM). Same profile as the DC.
  iam_instance_profile = data.terraform_remote_state.security.outputs.ec2_tf_automation_instance_profile_name

  # Linux connector variables (Windows-only deploy -> count 0 in tfvars)
  linux_ami_id                    = local.linux_ami_id
  linux_security_group_ids        = data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  linux_connector_count           = var.linux_connector_count
  linux_connector_hostname_prefix = var.linux_connector_hostname_prefix
  linux_connector_name_prefix     = var.linux_connector_name_prefix
  private_key_contents            = data.conjur_secret.aws_pem_key.value

  # Domain join (Improvement #2, direct WinRM) + SIA connector (Improvement #3)
  domain_name          = var.domain_name
  domain_ou_path       = var.domain_ou_path
  domain_join_username = data.conjur_secret.domain_join_username.value
  domain_join_password = data.conjur_secret.domain_join_password.value
  connector_pool_id    = data.terraform_remote_state.idira_connector_pools.outputs.connector_manager_pool_id

  # Local Administrator vaulting (Improvement #1)
  connector_safe_name               = var.connector_safe_name
  connector_safe_description        = var.connector_safe_description
  connector_safe_retention_days     = var.connector_safe_retention_days
  connector_local_admin_platform_id = var.connector_local_admin_platform_id
}

/* ITERATION 1 (DC only): targets + kind_node remain disabled. Re-enable later.
module "targets" {
  source                                  = "./ec2_instances/targets"
  vpc_id                                  = data.terraform_remote_state.foundation.outputs.vpc_id
  team_name                               = var.team_name
  asset_owner_name                        = var.asset_owner_name
  key_name                                = data.terraform_remote_state.security.outputs.key_name
  iScheduler                              = var.iScheduler
  linux_ami_id                            = local.linux_ami_id
  windows_security_group_ids              = [data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id, data.terraform_remote_state.foundation.outputs.sia_windows_target_sg_id]
  linux_security_group_ids                = data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  private_subnet_id                       = data.terraform_remote_state.foundation.outputs.private_subnet_id
  windows_target_1_private_ip             = var.windows_target_1_private_ip
  linux_target_1_private_ip               = var.linux_target_1_private_ip
  region                                  = var.region
  identity_tenant_id                      = var.identity_tenant_id
  platform_tenant_name                    = var.platform_tenant_name
  workspace_id                            = data.aws_caller_identity.current.account_id
  workspace_type                          = var.workspace_type
  linux_target_1_hostname                 = var.linux_target_1_hostname
  identity_client_id                      = data.conjur_secret.identity_client_id.value
  identity_client_secret                  = data.conjur_secret.identity_client_secret.value
  windows_ami_id                          = local.windows_ami_id
  ec2_tf_automation_instance_profile_name = data.terraform_remote_state.security.outputs.ec2_tf_automation_instance_profile_name
}

# =====================================================================
# KIND KUBERNETES NODE
# =====================================================================
module "kind_node" {
  source                   = "./ec2_instances/kind_node"
  linux_ami_id             = local.linux_ami_id
  key_name                 = data.terraform_remote_state.security.outputs.key_name
  team_name                = var.team_name
  asset_owner_name         = var.asset_owner_name
  iScheduler               = var.iScheduler
  linux_security_group_ids = data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  private_subnet_id        = data.terraform_remote_state.foundation.outputs.private_subnet_id
  kind_node_private_ip     = var.kind_node_private_ip
  kind_node_hostname       = var.kind_node_hostname
  private_key_contents     = data.conjur_secret.aws_pem_key.value

  # SWA (Secure Workload Access) layer — off unless enabled with tenant inputs.
  enable_swa_workloads    = var.enable_swa_workloads
  swa_agent_helm_repo_url = var.swa_agent_helm_repo_url
  swa_agent_chart         = var.swa_agent_chart
  swa_agent_chart_version = var.swa_agent_chart_version
  swa_agent_enrollment_token = (
    var.enable_swa_workloads && var.swa_agent_enrollment_token_path != ""
    ? data.conjur_secret.swa_agent_enrollment_token[0].value
    : var.swa_agent_enrollment_token
  )
}
*/
