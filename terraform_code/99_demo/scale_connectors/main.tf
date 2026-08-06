# =====================================================================
# Demo: Scale SIA Connectors on Demand
#
# This is a self-contained demonstration that shows how to scale CyberArk
# SIA (Secure Infrastructure Access) connectors up or down with a single
# variable:
#
#   1. Deploy N raw Amazon Linux EC2 instances (N = var.connector_count)
#   2. Register EACH instance as a SIA connector in an existing connector
#      pool using the idsec provider (idsec_sia_access_connector)
#
# Change var.connector_count, re-apply, and Terraform adds/removes both the
# EC2 hosts and their connector registrations to match.
#
# Pool wiring: the connector pool is created in 03_idira_config/connector_pools.
# We consume its pool_id via remote state — nothing about the pool is defined
# here, so this demo only ever adds/removes connectors, never the pool itself.
#
# This is modeled on the commented-out Linux connector skeleton from
# 04_ec2_compute and the linux_target demo in this folder.
# =====================================================================

# =====================================================================
# Provider: Conjur - For retrieving secrets
# =====================================================================
provider "conjur" {
  appliance_url = var.conjur_appliance_url
  account       = var.conjur_account
  authn_type    = var.conjur_authn_type == "iam" ? "aws" : "api"

  # API key auth (laptop) — null when using IAM
  login   = var.conjur_authn_type == "api" ? var.conjur_login : null
  api_key = var.conjur_authn_type == "api" ? var.conjur_api_key : null

  # IAM auth (EC2) — null when using API key
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

data "conjur_secret" "identity_client_id" {
  name = var.conjur_identity_client_id_path
}

data "conjur_secret" "identity_client_secret" {
  name = var.conjur_identity_client_secret_path
}

# The EC2 key pair private key (vaulted in 02_security, synced to Conjur).
# Used as the SSH credential the idsec provider uses to reach each instance
# and install the SIA connector.
data "conjur_secret" "aws_pem_key" {
  name = var.conjur_aws_pem_key_path
}

# =====================================================================
# Provider: AWS
# =====================================================================
provider "aws" {
  region     = var.region
  access_key = var.conjur_authn_type == "api" ? data.conjur_secret.aws_access_key[0].value : null
  secret_key = var.conjur_authn_type == "api" ? data.conjur_secret.aws_secret_key[0].value : null
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
# Data Sources: Remote State (Foundation Layer)
#   Source of the private subnet and internal SSH security group.
# =====================================================================
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.foundation_state_key
    region = var.state_region
  }
}

# =====================================================================
# Data Sources: Remote State (Security Layer)
#   Source of the AWS EC2 key pair created/vaulted in 02_security.
# =====================================================================
data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.security_state_key
    region = var.state_region
  }
}

# =====================================================================
# Data Sources: Remote State (Connector Pools — 03_idira_config)
#   Source of the connector pool the new connectors join. The pool and its
#   network/identifiers are defined in 03; we only read the pool_id here.
# =====================================================================
data "terraform_remote_state" "connector_pools" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = var.connector_pools_state_key
    region = var.state_region
  }
}

# =====================================================================
# Data Sources: Get Latest Amazon Linux AMI
# =====================================================================
data "aws_ami" "amazon_linux_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# =====================================================================
# EC2 Instances: N connector hosts (Amazon Linux 2023)
#
# One raw instance per connector. Bump var.connector_count and re-apply to
# scale the fleet; Terraform creates/destroys the extra hosts for you.
# =====================================================================
resource "aws_instance" "connector" {
  count = var.connector_count

  ami                         = data.aws_ami.amazon_linux_latest.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.foundation.outputs.private_subnet_id
  associate_public_ip_address = false
  key_name                    = data.terraform_remote_state.security.outputs.key_name
  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  ]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    hostnamectl set-hostname "${var.hostname_prefix}-${count.index + 1}"
  EOF

  tags = {
    Name                 = "${var.team_name}-${var.hostname_prefix}-${count.index + 1}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "SIA Connector (scale demo)"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =====================================================================
# SIA Access Connectors: register each EC2 host as a connector in the pool
#
# The idsec provider SSHes to each instance's private IP (using the vaulted
# EC2 key pair) and installs + registers the SIA connector into the pool
# created in 03_idira_config/connector_pools.
# =====================================================================
resource "idsec_sia_access_connector" "connector" {
  count = var.connector_count

  connector_type    = var.connector_type
  connector_os      = var.connector_os
  connector_pool_id = data.terraform_remote_state.connector_pools.outputs.connector_manager_pool_id

  target_machine       = aws_instance.connector[count.index].private_ip
  username             = var.connector_username
  private_key_contents = data.conjur_secret.aws_pem_key.value

  depends_on = [aws_instance.connector]
}
