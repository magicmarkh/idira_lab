# =====================================================================
# 04_ec2_compute — AMI data sources, remote state, and locals
#
# This layer deploys four RAW EC2 instances (a DC, a Windows connector, a
# Windows target, and a Linux target) with NO in-instance configuration
# automation, and vaults each system's local credential into CyberArk.
# The instances are defined in instances.tf; the safes + vaulted accounts
# in vault.tf.
# =====================================================================

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
# The SSH key pair is generated and vaulted in 02_security (so it exists
# before any compute). We consume the key NAME via remote state; the private
# key lives in Conjur (data.conjur_secret.aws_pem_key) and is used both to
# decrypt EC2-generated Windows Administrator passwords (rsadecrypt) and as
# the vaulted Linux SSH credential.
