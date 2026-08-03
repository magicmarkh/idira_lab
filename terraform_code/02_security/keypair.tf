# =====================================================================
# AWS EC2 SSH key pair
#
# Generated here in 02_security (the security layer) so the key exists
# before any compute that consumes it. Only the key NAME is exported for
# downstream states (04_ec2_compute reads it via remote state); the
# private key is vaulted in Idira and synced to Conjur (see keypair_vault.tf),
# so consumers pull it from Conjur rather than from Terraform state.
# =====================================================================
resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 4096

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_key_pair" "server" {
  key_name   = "${var.team_name}-key"
  public_key = tls_private_key.server.public_key_openssh

  tags = {
    Name  = "${var.team_name}-key"
    Owner = var.asset_owner_name
  }

  lifecycle {
    ignore_changes = all
  }
}
