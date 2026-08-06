# =====================================================================
# Demo Windows Target with Idira Password Vaulting
#
# This is a self-contained demonstration that shows:
# 1. Deploying a Windows EC2 instance
# 2. Setting a secure local Administrator password
# 3. Joining to Active Directory domain
# 4. Creating a Idira safe
# 5. Vaulting the Administrator password in Idira
#
# All components are in this single file for easy demonstration.
# =====================================================================

# =====================================================================
# Provider: Conjur - For retrieving secrets
# =====================================================================
provider "conjur" {
  appliance_url = var.conjur_appliance_url
  account       = var.conjur_account
  authn_type    = var.conjur_authn_type == "iam" ? "aws" : "api"

  # API key auth (laptop)
  login   = var.conjur_authn_type == "api" ? var.conjur_login : null
  api_key = var.conjur_authn_type == "api" ? var.conjur_api_key : null

  # IAM auth (EC2)
  service_id = var.conjur_authn_type == "iam" ? var.conjur_authenticator_name : null
  host_id    = var.conjur_authn_type == "iam" ? var.conjur_host_id : null
}

# =====================================================================
# Data Sources: Conjur Secrets
# =====================================================================
data "conjur_secret" "aws_access_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_secret_key_path
}

data "conjur_secret" "domain_join_username" {
  name = var.conjur_domain_join_username_path
}

data "conjur_secret" "domain_join_password" {
  name = var.conjur_domain_join_password_path
}

data "conjur_secret" "identity_client_id" {
  name = var.conjur_identity_client_id_path
}

data "conjur_secret" "identity_client_secret" {
  name = var.conjur_identity_client_secret_path
}

# EC2 key pair private key (PEM), vaulted in Conjur. Used to decrypt the
# EC2-generated local Administrator password (rsadecrypt on password_data).
data "conjur_secret" "aws_pem_key" {
  name = var.conjur_aws_pem_key_path
}

# =====================================================================
# Provider: AWS
# =====================================================================
provider "aws" {
  region = var.region
  # When using API auth, AWS creds come from Conjur secrets.
  # When using IAM auth, these are null and the provider uses the EC2 instance profile.
  access_key = one(data.conjur_secret.aws_access_key[*].value)
  secret_key = one(data.conjur_secret.aws_secret_key[*].value)
}

# =====================================================================
# Provider: Idira Identity Security (IDSec)
# =====================================================================
provider "idsec" {
  auth_method   = "identity_service_user"
  service_user  = data.conjur_secret.identity_client_id.value
  service_token = data.conjur_secret.identity_client_secret.value
}

# =====================================================================
# Data Sources: Remote State (Foundation and Security Layers)
# =====================================================================
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/01_foundation.tfstate"
    region = "us-west-2"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/02_security.tfstate"
    region = "us-west-2"
  }
}

# Get latest Windows Server 2022 AMI
data "aws_ami" "windows_2022" {
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
}

# =====================================================================
# EC2 Instance: Windows Server 2022
# =====================================================================
resource "aws_instance" "demo_target" {
  ami                         = data.aws_ami.windows_2022.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.foundation.outputs.private_subnet_id
  associate_public_ip_address = false
  key_name                    = data.terraform_remote_state.security.outputs.key_name
  get_password_data           = true
  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.winrm_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.sia_windows_target_sg_id
  ]

  # User data: enable WinRM. The Administrator password is left to EC2Launch,
  # which generates it and encrypts it with the key pair's public key; Terraform
  # decrypts it with the Conjur-vaulted PEM (get_password_data / rsadecrypt).
  user_data = <<-EOT
    <powershell>
    # Enable WinRM (HTTP for lab)
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
    Enable-PSRemoting -Force
    </powershell>
  EOT

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-${var.hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Demo Windows Target - Idira Password Vaulting"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =====================================================================
# Local Values: Escaped passwords for shell commands
# =====================================================================
locals {
  # EC2 generates the Administrator password and encrypts it with the key pair's
  # public key; we decrypt it in Terraform with the Conjur-vaulted PEM so the same
  # value drives the Ansible domain-join and the Idira vault account.
  admin_password = rsadecrypt(aws_instance.demo_target.password_data, data.conjur_secret.aws_pem_key.value)

  # Ansible extra-vars are written to a temporary YAML file (see the local-exec
  # provisioners below) and consumed with `-e @file` instead of inline
  # `-e key=value`. Inline extra-vars run through Ansible's Jinja-aware argument
  # splitter, so a password containing `{{` aborts with "unbalanced jinja2
  # block". YAML single-quoted scalars only require doubling embedded single
  # quotes; the `!unsafe` tag on the value in the file then stops Ansible from
  # templating it, so `{{`, `$`, quotes, and backslashes all pass through
  # verbatim.
  admin_password_yaml  = replace(local.admin_password, "'", "''")
  domain_password_yaml = replace(data.conjur_secret.domain_join_password.value, "'", "''")
}

# =====================================================================
# Domain Join: Ansible Provisioner
# =====================================================================
resource "terraform_data" "domain_operations" {
  # Store values needed for destroy-time provisioner
  # These must be stored in triggers_replace to be available during destroy
  triggers_replace = {
    instance_id     = aws_instance.demo_target.id
    instance_ip     = aws_instance.demo_target.private_ip
    admin_password  = local.admin_password
    domain_user     = "${data.conjur_secret.domain_join_username.value}@${var.domain_name}"
    domain_password = data.conjur_secret.domain_join_password.value
    domain_name     = var.domain_name
    domain_ou_path  = var.domain_ou_path
    hostname        = var.hostname
  }

  # Output ensures this resource is in the dependency graph
  input = aws_instance.demo_target.id

  # Create-time provisioner: Join domain
  provisioner "local-exec" {
    command = <<EOT
cd ../../../ansible
VARS_DIR="$(mktemp -d)"
cat > "$VARS_DIR/extra_vars.yml" <<'ANSIBLE_VARS'
ansible_user: Administrator
ansible_password: !unsafe '${local.admin_password_yaml}'
ansible_connection: winrm
ansible_port: 5985
ansible_winrm_scheme: http
ansible_winrm_server_cert_validation: ignore
hostname: '${var.hostname}'
domain_join_username: '${data.conjur_secret.domain_join_username.value}@${var.domain_name}'
domain_join_password: !unsafe '${local.domain_password_yaml}'
domain_name: '${var.domain_name}'
domain_ou_path: '${var.domain_ou_path}'
ANSIBLE_VARS
ansible-playbook \
  -i '${aws_instance.demo_target.private_ip},' \
  -e @"$VARS_DIR/extra_vars.yml" \
  playbooks/onboard_windows_connector.yml
RESULT=$?
rm -rf "$VARS_DIR"
exit $RESULT
EOT
  }

  # Destroy-time provisioner: Unjoin from domain
  # This will run BEFORE the instance is destroyed if proper order is followed
  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
echo "==================== DOMAIN UNJOIN STARTING ===================="
echo "Target IP: ${self.triggers_replace.instance_ip}"
echo "Hostname: ${self.triggers_replace.hostname}"
echo "Connecting as: local Administrator account"
echo "==============================================================="

cd ../../../ansible
VARS_DIR="$(mktemp -d)"
cat > "$VARS_DIR/extra_vars.yml" <<'ANSIBLE_VARS'
ansible_user: Administrator
ansible_password: !unsafe '${replace(self.triggers_replace.admin_password, "'", "''")}'
ansible_connection: winrm
ansible_port: 5985
ansible_winrm_scheme: http
ansible_winrm_server_cert_validation: ignore
domain_admin_user: '${self.triggers_replace.domain_user}'
domain_admin_password: !unsafe '${replace(self.triggers_replace.domain_password, "'", "''")}'
domain_name: '${self.triggers_replace.domain_name}'
ANSIBLE_VARS
ansible-playbook \
  -i '${self.triggers_replace.instance_ip},' \
  -e @"$VARS_DIR/extra_vars.yml" \
  playbooks/unjoin_domain.yml

UNJOIN_RESULT=$?
rm -rf "$VARS_DIR"
if [ $UNJOIN_RESULT -eq 0 ]; then
  echo "==================== DOMAIN UNJOIN SUCCESSFUL ===================="
else
  echo "==================== DOMAIN UNJOIN FAILED (exit code: $UNJOIN_RESULT) ===================="
  echo "WARNING: Instance will remain joined to domain!"
  exit $UNJOIN_RESULT
fi
EOT

    # Make failures visible - do NOT continue on failure
    # This ensures you know if unjoin fails
    on_failure = fail
  }

  # Explicit dependency: domain operations depend on instance existing
  depends_on = [aws_instance.demo_target]
}


# =====================================================================
# Idira Safe: For storing the Administrator password
# =====================================================================
resource "idsec_pcloud_safe" "demo_target_safe" {
  safe_name                = var.safe_name
  description              = var.safe_description
  number_of_days_retention = var.safe_retention_days

  depends_on = [aws_instance.demo_target] # Ensure instance creation is successful before creating a safe to vault account
}

# =====================================================================
# Idira Account: Vault the Administrator password
# =====================================================================
resource "idsec_pcloud_account" "demo_target_admin" {
  platform_id = var.platform_id
  username    = "Administrator"
  address     = "${var.hostname}.${var.domain_name}"
  secret      = local.admin_password # EC2-generated Administrator password, decrypted via the vaulted PEM
  safe_name   = idsec_pcloud_safe.demo_target_safe.safe_name
  name        = "${var.hostname}-admin"

  depends_on = [idsec_pcloud_safe.demo_target_safe] # Ensure safe is created before vaulting account

  lifecycle {
    ignore_changes = [
      secret,                     # CPM rotates passwords after initial creation
      name,                       # Idira manages naming
      secret_type,                # Computed by Idira
      platform_account_properties # Platform-specific settings
    ]
  }
}
