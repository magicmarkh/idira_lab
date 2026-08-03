# =====================================================================
# Domain Controller — instance + WinRM bootstrap + SSM-driven promotion
# =====================================================================
# The DC lives in a private subnet with no public IP. We bootstrap WinRM
# (HTTP 5985) via user_data, then reach it from outside the VPC through an
# AWS SSM port-forwarding tunnel to run the Ansible domain_controller role
# (see scripts/promote_via_ssm.sh and ../../../ansible).

# The local Administrator password is NOT self-authored. EC2 generates a random
# password at first boot and encrypts it with the key pair's public key; the
# promotion step decrypts it with the Conjur-vaulted PEM (get-password-data).

# Directory Services Restore Mode (safe-mode) password for the forest.
# Generated here and handed to the promotion playbook; never needs to leave TF.
resource "random_password" "dsrm" {
  length           = 24
  special          = true
  override_special = "!@#%^*()-_=+[]{}"
}

# Password for the domain-join service account created in AD during the build.
# Surfaced as a (sensitive) output for later iterations (Privilege Cloud vaulting).
resource "random_password" "domain_join" {
  length           = 24
  special          = true
  override_special = "!@#%^*()-_=+[]{}"
}

locals {
  # No template vars: EC2 owns the Administrator password now.
  user_data = file("${path.module}/scripts/user_data.tpl")

  # EC2 generates the Administrator password and encrypts it with the key pair's
  # public key; only the private key can decrypt it. We decrypt in Terraform with
  # the Conjur-vaulted PEM so the same value feeds BOTH the promotion (Ansible) and
  # the Idira vault account. (get_password_data on the instance makes the encrypted
  # blob available; the AWS provider blocks on create until it is posted.)
  admin_password = rsadecrypt(aws_instance.us-ent-east-dc1.password_data, var.private_key_pem)
}

resource "aws_instance" "us-ent-east-dc1" {
  ami                         = var.windows_ami_id
  instance_type               = var.windows_instance_type
  subnet_id                   = var.private_subnet_id
  associate_public_ip_address = false
  key_name                    = var.key_name
  vpc_security_group_ids      = var.security_group_ids
  private_ip                  = var.private_ip
  disable_api_termination     = true
  user_data                   = local.user_data
  iam_instance_profile        = var.iam_instance_profile
  get_password_data           = true

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-dc1"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Murphy's Lab Domain Controller"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes  = [tags, ami, user_data]
    prevent_destroy = false
  }
}

# Promote the forest + build AD content over an SSM port-forward tunnel.
# The wrapper opens localhost:55985 -> DC:5985, waits for the tunnel, runs the
# setup_domain_controller.yml playbook against 127.0.0.1, then tears it down.
resource "null_resource" "promote_dc" {
  depends_on = [aws_instance.us-ent-east-dc1]

  # Re-run if the instance is replaced.
  triggers = {
    instance_id = aws_instance.us-ent-east-dc1.id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/promote_via_ssm.sh"

    environment = {
      SSM_INSTANCE_ID = aws_instance.us-ent-east-dc1.id
      AWS_REGION      = var.region
      LOCAL_PORT      = "55985"
      # Conjur-sourced automation creds (API mode); empty in IAM mode. The script
      # only exports these to the aws CLI when both are non-empty, so IAM mode
      # keeps using the instance role.
      AWS_ACCESS_KEY_ID_OVERRIDE     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY_OVERRIDE = var.aws_secret_access_key
      ANSIBLE_DIR                    = abspath("${path.module}/../../../../ansible")
      # Administrator password: EC2-generated, decrypted in TF with the vaulted PEM.
      DC_ADMIN_PASSWORD           = local.admin_password
      DC_DOMAIN_FQDN              = var.domain_name
      DC_DOMAIN_NETBIOS           = var.domain_netbios
      DC_DSRM_PASSWORD            = random_password.dsrm.result
      DC_SERVICE_ACCOUNT_NAME     = var.service_account_name
      DC_SERVICE_ACCOUNT_PASSWORD = random_password.domain_join.result
    }
  }
}

# Absorb AD / DNS / AD Web Services warm-up after promotion completes.
resource "time_sleep" "wait_after_promote" {
  depends_on      = [null_resource.promote_dc]
  create_duration = "180s"
}
