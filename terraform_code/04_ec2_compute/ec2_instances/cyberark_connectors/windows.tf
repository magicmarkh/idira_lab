locals {
  user_data = file("${path.module}/scripts/user_data.tpl")

  # The local Administrator password is NOT self-authored. EC2 generates it at
  # first boot and encrypts it with the key pair's public key; we decrypt it in
  # Terraform with the Conjur-vaulted PEM so the same value drives the Ansible
  # domain-join. (get_password_data blocks the create until the encrypted blob is
  # posted by the instance.)
  admin_password = rsadecrypt(aws_instance.connector_1.password_data, var.private_key_contents)
}

resource "aws_instance" "connector_1" {
  ami                         = var.windows_ami_id
  instance_type               = var.windows_instance_type
  subnet_id                   = var.private_subnet_id
  associate_public_ip_address = false
  key_name                    = var.key_name
  vpc_security_group_ids      = var.windows_security_group_ids
  private_ip                  = var.connector_1_private_ip
  disable_api_termination     = true
  user_data                   = local.user_data
  get_password_data           = true

  # Instance profile attached to the connector (retains break-glass SSM access;
  # the Ansible domain join connects directly over WinRM, not via SSM).
  iam_instance_profile = var.iam_instance_profile

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name                 = "${var.team_name}-connector-1"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Murphy's Lab primary CyberArk Connector"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes  = [tags, ami, user_data]
    prevent_destroy = false
  }
}

# Improvement #2 — join the domain by running the Ansible windows_connector role
# directly against the connector's private IP over WinRM. No wrapper script, no SSM:
# the playbook reads every connection/role value from the environment below via
# lookup('env', ...). Terraform is expected to run from inside the VPC (winrm_internal
# SG allows 5985). The role's wait_for_connection absorbs cold-boot and the domain-join
# reboot (it reconnects to the same IP).
resource "null_resource" "join_domain" {
  depends_on = [aws_instance.connector_1]

  # Re-run if the instance is replaced.
  triggers = {
    instance_id = aws_instance.connector_1.id
  }

  provisioner "local-exec" {
    working_dir = abspath("${path.module}/../../../../ansible")
    command     = "ansible-galaxy collection install -r requirements.yml && ansible-playbook -i '${aws_instance.connector_1.private_ip},' playbooks/onboard_windows_connector.yml"

    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      # Administrator password: EC2-generated, decrypted in TF with the vaulted PEM.
      CONNECTOR_ADMIN_PASSWORD = local.admin_password
      CONNECTOR_HOSTNAME       = var.windows_connector_hostname
      DOMAIN_NAME              = var.domain_name
      DOMAIN_JOIN_USERNAME     = "${var.domain_join_username}@${var.domain_name}"
      DOMAIN_JOIN_PASSWORD     = var.domain_join_password
      DOMAIN_OU_PATH           = var.domain_ou_path
    }
  }
}

# Wait for Windows server to fully stabilize after domain join and reboot
resource "time_sleep" "wait_after_domain_join" {
  depends_on = [null_resource.join_domain]

  create_duration = "180s" # Wait 3 minutes for server to be fully ready
}

# Improvement #3 — register the connector as a SIA access connector.
#
# idsec_sia_access_connector push-installs the connector by connecting from the host
# running Terraform to target_machine and running the installer remotely — over WinRM
# for Windows, exactly as linux.tf does over SSH. This requires Terraform to be run
# from a host with network reachability to the connector's private IP (in-VPC or over
# VPN); it is not an agentless registration. Mirror linux.tf: point target_machine at
# the private IP and let the provider handle the WinRM session.
resource "idsec_sia_access_connector" "windows_connector" {
  connector_type    = "AWS"
  connector_os      = "windows"
  connector_pool_id = var.connector_pool_id
  target_machine    = aws_instance.connector_1.private_ip
  # Local Administrator: always has WinRM/admin rights, and local.admin_password (the
  # EC2-generated blob decrypted with the vaulted PEM) is the same credential the
  # Ansible domain-join used successfully. Domain join does not change the local
  # Administrator password, so it is still valid here.
  username       = "Administrator"
  password       = local.admin_password
  winrm_protocol = "http"
  depends_on     = [time_sleep.wait_after_domain_join]

  lifecycle {
    ignore_changes = [
      connector_id,
      password,
      private_key_contents,
      private_key_path
    ]
  }
}
