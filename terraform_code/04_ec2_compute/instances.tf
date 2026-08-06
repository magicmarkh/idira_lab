# =====================================================================
# Raw EC2 instances — NO configuration automation
#
# Four instances (a DC, a Windows connector, a Windows target, and a Linux
# target) are deployed bare. There is no Ansible, no DC promotion, no domain
# join, no SIA registration, no user_data bootstrap beyond a Linux hostname.
# The user configures them manually. Access is via AWS SSM Session Manager /
# Fleet Manager (the automation instance profile from 02_security carries
# AmazonSSMManagedInstanceCore), plus RDP/SSH on the internal SGs.
#
# All three Windows boxes set get_password_data = true so Terraform can pull
# the EC2-generated Administrator password and vault it (see vault.tf). This
# can make the create take a few minutes on first boot while EC2 posts the
# encrypted blob — that is expected, not a hang.
# =====================================================================

locals {
  instance_profile = data.terraform_remote_state.security.outputs.ec2_tf_automation_instance_profile_name
  key_name         = data.terraform_remote_state.security.outputs.key_name
  subnet_id        = data.terraform_remote_state.foundation.outputs.private_subnet_id
}

# ---------------------------------------------------------------------
# Domain Controller (Windows) — raw; promote manually later
# ---------------------------------------------------------------------
resource "aws_instance" "dc" {
  ami                         = local.windows_ami_id
  instance_type               = var.dc_instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = false
  private_ip                  = var.dc1_private_ip
  key_name                    = local.key_name
  iam_instance_profile        = local.instance_profile
  get_password_data           = true

  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.domain_controller_sg_id,
  ]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-${var.dc_hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Domain Controller (raw - configure manually)"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------------------------------------------------------------
# Windows CyberArk connector — raw
# ---------------------------------------------------------------------
resource "aws_instance" "connector" {
  ami                         = local.windows_ami_id
  instance_type               = var.connector_instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = false
  private_ip                  = var.connector_1_private_ip
  key_name                    = local.key_name
  iam_instance_profile        = local.instance_profile
  get_password_data           = true

  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.https_internal_flat_sg_id,
  ]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-${var.windows_connector_hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Windows connector (raw - configure manually)"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------------------------------------------------------------
# Windows target — raw
# ---------------------------------------------------------------------
resource "aws_instance" "windows_target" {
  ami                         = local.windows_ami_id
  instance_type               = var.windows_target_instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = false
  private_ip                  = var.windows_target_1_private_ip
  key_name                    = local.key_name
  iam_instance_profile        = local.instance_profile
  get_password_data           = true

  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.rdp_internal_flat_sg_id,
    data.terraform_remote_state.foundation.outputs.sia_windows_target_sg_id,
  ]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-${var.windows_target_hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Windows target (raw - configure manually)"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ---------------------------------------------------------------------
# Linux target (Amazon Linux 2023) — raw (hostname only)
# ---------------------------------------------------------------------
resource "aws_instance" "linux_target" {
  ami                         = local.linux_ami_id
  instance_type               = var.linux_target_instance_type
  subnet_id                   = local.subnet_id
  associate_public_ip_address = false
  private_ip                  = var.linux_target_1_private_ip
  key_name                    = local.key_name
  iam_instance_profile        = local.instance_profile

  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id,
  ]

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    hostnamectl set-hostname "${var.linux_target_1_hostname}"

    # Base tooling: git, pip, and Terraform.
    dnf install -y git python3-pip dnf-plugins-core

    # Ansible + control-node libraries.
    #   pywinrm  -> required by the winrm connection plugin for Windows targets
    #               (99_demo/windows_target domain join). Installed on the
    #               CONTROL node's Python; without it Ansible fails with
    #               "No module named 'winrm'".
    pip3 install --user ansible pywinrm
    export PATH="$HOME/.local/bin:$PATH"

    # Ansible Galaxy collections. Keep this list in sync with
    # ansible/requirements.yml (the canonical source). Installed into the
    # system-wide path so any login user's ansible run can find them.
    #   microsoft.ad / ansible.windows / community.windows -> Windows domain join
    #   amazon.aws / community.aws                          -> aws_ssm connection (98_dev)
    ansible-galaxy collection install -p /usr/share/ansible/collections \
      'microsoft.ad:>=1.7.0,<2.0.0' \
      'ansible.windows:>=2.5.0,<3.0.0' \
      'community.windows:>=2.3.0,<3.0.0' \
      'amazon.aws:>=8.0.0,<10.0.0' \
      'community.aws:>=8.0.0,<10.0.0'

    # Terraform from the official HashiCorp repo.
    dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
    dnf install -y terraform
  EOF

  tags = {
    Name                 = "${var.team_name}-${var.linux_target_1_hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Linux target (raw - configure manually)"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
