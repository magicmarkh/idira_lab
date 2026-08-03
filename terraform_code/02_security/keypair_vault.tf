# =====================================================================
# Vault the AWS EC2 SSH private key in Idira
#
# Creates a dedicated safe, adds members (including "Conjur Sync", which
# triggers Secrets Hub replication into Conjur), and stores the private
# key generated in keypair.tf as an Idira account. Downstream consumers
# (connectors, targets, kind node, demo hosts) read the key from Conjur
# at data/vault/<safe>/<account>/<property> instead of from Terraform
# state, so the key never has to live locally.
#
# The account uses an UNMANAGED platform: Idira stores the key but does
# not rotate it (the EC2 key pair is immutable once instances are launched
# against it). `secret` is in ignore_changes so re-applies never churn it.
# =====================================================================

# ---------------------------------------------------------------------
# Safe (+ members) for the AWS EC2 private key
# ---------------------------------------------------------------------
module "keypair_safe" {
  source = "../modules/idira/safe"

  safe_name      = var.keypair_safe_name
  description    = "AWS EC2 SSH private key storage"
  retention_days = 7
  members        = var.keypair_safe_members
}

# ---------------------------------------------------------------------
# AWS EC2 private key account
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "keypair" {
  platform_id = var.keypair_account_platform_id
  username    = "${var.team_name}-key.pem"
  address     = data.aws_caller_identity.current.account_id
  secret      = tls_private_key.server.private_key_pem
  safe_name   = module.keypair_safe.safe_name
  name        = var.keypair_account_name

  lifecycle {
    ignore_changes = [
      secret,                      # stored once; the EC2 key pair is immutable
      name,                        # set on create
      secret_type,                 # set server-side
      platform_account_properties, # unmanaged platform may set defaults
      address                      # cannot be modified on existing accounts
    ]
  }

  depends_on = [module.keypair_safe]
}
