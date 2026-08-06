# =====================================================================
# mh_dev — standalone Linux dev host (Amazon Linux 2023)
#
# A self-contained layer that deploys a private-subnet dev box at a static
# IP and installs Ansible + Terraform on it. Access is via AWS SSM Session
# Manager (no public SSH, no SIA). Provisioning runs the existing AL2023
# playbook over the community.aws.aws_ssm connection plugin — so there is no
# SSH key / PEM and no inbound SSH involved.
#
# Modeled on 99_demo/linux_target (layer shape) and
# 04_ec2_compute/ec2_instances/kind_node (Ansible via null_resource).
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
# Data Sources: Conjur Secrets (AWS provider creds, API-key mode only)
# =====================================================================
data "conjur_secret" "aws_access_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_secret_key_path
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
# Data Sources: Remote State (Foundation + Security layers)
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

# =====================================================================
# Data Sources: Get Latest Amazon Linux 2023 AMI
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
# EC2 Instance: mh_dev (Amazon Linux 2023)
#
# Attaches the automation instance profile from 02_security, which carries
# AmazonSSMManagedInstanceCore (SSM access) plus EC2/IAM and scoped S3
# access to the state bucket — so the box can run Terraform in-VPC and reach
# shared state via the S3 gateway endpoint.
# =====================================================================
resource "aws_instance" "mh_dev" {
  ami                         = data.aws_ami.amazon_linux_latest.id
  instance_type               = var.instance_type
  subnet_id                   = data.terraform_remote_state.foundation.outputs.private_subnet_id
  associate_public_ip_address = false
  private_ip                  = var.private_ip
  key_name                    = var.key_name != null ? var.key_name : data.terraform_remote_state.security.outputs.key_name
  iam_instance_profile        = data.terraform_remote_state.security.outputs.ec2_tf_automation_instance_profile_name
  vpc_security_group_ids = [
    data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  ]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    hostnamectl set-hostname "${var.hostname}"
  EOF

  tags = {
    Name                 = "${var.team_name}-${var.hostname}"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Dev host - Ansible/Terraform"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# =====================================================================
# Ansible provisioning over SSM
#
# Installs Ansible + Terraform via the existing AL2023 playbook. Uses the
# community.aws.aws_ssm connection plugin (no SSH, no key): it targets the
# instance ID and stages files through the S3 transfer bucket. The control
# node needs AWS creds (same chain as the S3 backend), session-manager-plugin,
# boto3, and the amazon.aws/community.aws collections installed.
# =====================================================================
locals {
  # path.module is terraform_code/98_dev — two levels below the repo root,
  # where the shared ansible/ directory lives.
  ansible_dir = abspath("${path.module}/../../ansible")
}

resource "null_resource" "setup_mh_dev" {
  depends_on = [aws_instance.mh_dev]

  triggers = {
    instance_id = aws_instance.mh_dev.id
  }

  provisioner "local-exec" {
    working_dir = local.ansible_dir

    # macOS control nodes crash forked Ansible workers ("A worker was found in a
    # dead state") when boto3/the aws_ssm plugin runs under the default
    # fork-safety rules. These two env vars are the standard fix; harmless on Linux.
    environment = {
      OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES"
      no_proxy                            = "*"
    }

    command = <<EOT
set -e
INSTANCE_ID='${aws_instance.mh_dev.id}'
REGION='${var.region}'

# The SSM agent reports PingStatus=Online before its ssmmessages data channel is
# actually ready to accept sessions — running Ansible in that gap fails with
# TargetNotConnected. So gate on a real non-interactive session succeeding, not
# just on Online. (The plugin prints a harmless "...EOF" line on exit; we key off
# the sentinel in the command output instead of the exit code.)
echo "Waiting for the SSM data channel on $INSTANCE_ID..."
READY=""
for i in $(seq 1 30); do
  OUT=$(echo | aws ssm start-session --region "$REGION" --target "$INSTANCE_ID" \
    --document-name AWS-StartNonInteractiveCommand \
    --parameters '{"command":["echo SSM_READY"]}' 2>/dev/null || true)
  if echo "$OUT" | grep -q SSM_READY; then
    echo "SSM data channel ready"
    READY=1
    break
  fi
  echo "Attempt $i/30 - waiting 10s..."
  sleep 10
done
[ -n "$READY" ] || { echo "SSM data channel never became ready" >&2; exit 1; }

# Provision over SSM using the existing AL2023 playbook.
# SSM Session Manager connects as ssm-user (not ec2-user), so do NOT set
# ansible_user — the playbook's `become: yes` escalates to root via ssm-user's
# passwordless sudo. Root the remote tmp under /tmp so the login user can write
# it (its home dir may not exist / be writable).
ansible-playbook \
  -i "$INSTANCE_ID," \
  -e "ansible_connection=community.aws.aws_ssm" \
  -e "ansible_aws_ssm_bucket_name=${var.ssm_transfer_bucket}" \
  -e "ansible_aws_ssm_region=${var.region}" \
  -e "ansible_remote_tmp=/tmp/.ansible/tmp" \
  -e "ansible_python_interpreter=/usr/bin/python3" \
  playbooks/setup_al2023_terraform_host.yml
EOT
  }
}
