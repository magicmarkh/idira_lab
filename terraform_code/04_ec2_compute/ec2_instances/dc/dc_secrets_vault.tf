# =====================================================================
# Vault the DC's privileged accounts in Idira (synced to Conjur)
#
# The DC build produces three privileged credentials that previously were
# discarded or only surfaced as outputs:
#   - Domain Administrator (EC2-generated, decrypted in TF via the vaulted PEM)
#   - DSRM / safe-mode recovery password (random_password.dsrm)
#   - svc-domain-joiner service account   (random_password.domain_join)
#
# They are stored in a dedicated safe whose "Conjur Sync" member triggers
# Secrets Hub replication into Conjur at
#   data/vault/<safe>/<account_name>/password
#
# Platforms are CPM-managed (rotating). NOTE: rotation requires a CPM with
# network line-of-sight to the DC (private subnet, SSM-only today) — until an
# in-VPC connector/CPM exists (Iteration 2), the initial secret is stored and
# synced, but rotation/verification will not succeed yet. `secret` is in
# ignore_changes so re-applies never revert a CPM-rotated value.
#
# The accounts depend on the promotion completing so the corresponding AD
# objects exist before Idira attempts to manage them.
# =====================================================================

# ---------------------------------------------------------------------
# Safe (+ members) for the DC privileged accounts
# ---------------------------------------------------------------------
module "dc_secrets_safe" {
  source = "../../../modules/idira/safe"

  safe_name      = var.dc_secrets_safe_name
  description    = "Domain controller privileged accounts (Domain Admin, DSRM)"
  retention_days = 7
  members        = var.dc_secrets_safe_members
}

# ---------------------------------------------------------------------
# Safe (+ members) for domain service accounts (svc-domain-joiner, etc.)
# Kept separate from the DC-secrets safe so service accounts consumed by other
# layers (e.g. the connector's Ansible domain join) have their own scope.
# ---------------------------------------------------------------------
module "service_accounts_safe" {
  source = "../../../modules/idira/safe"

  safe_name      = var.service_accounts_safe_name
  description    = "Domain service accounts (domain-join, etc.)"
  retention_days = 7
  members        = var.service_accounts_safe_members
}

# ---------------------------------------------------------------------
# Domain Administrator
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "domain_admin" {
  platform_id = var.domain_admin_platform_id
  username    = "Administrator"
  address     = var.domain_name
  secret      = local.admin_password
  safe_name   = module.dc_secrets_safe.safe_name
  name        = var.domain_admin_account_name

  lifecycle {
    ignore_changes = [
      secret,                      # rotated by the CPM
      platform_account_properties, # platform may set defaults
      address,                     # cannot be modified on existing accounts
      secret_type                  # set server-side
    ]
  }

  depends_on = [module.dc_secrets_safe, null_resource.promote_dc]
}

# ---------------------------------------------------------------------
# DSRM / safe-mode recovery password (per-DC local secret)
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "dsrm" {
  platform_id = var.dsrm_platform_id
  username    = "Administrator"
  address     = var.private_ip
  secret      = random_password.dsrm.result
  safe_name   = module.dc_secrets_safe.safe_name
  name        = var.dsrm_account_name

  lifecycle {
    ignore_changes = [
      secret,
      platform_account_properties,
      address,
      secret_type
    ]
  }

  depends_on = [module.dc_secrets_safe, null_resource.promote_dc]
}

# ---------------------------------------------------------------------
# Domain-join service account (svc-domain-joiner)
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "domain_join_svc" {
  platform_id = var.domain_join_platform_id
  username    = var.service_account_name
  address     = var.domain_name
  secret      = random_password.domain_join.result
  safe_name   = module.service_accounts_safe.safe_name
  name        = var.domain_join_account_name

  lifecycle {
    ignore_changes = [
      secret,
      platform_account_properties,
      address,
      secret_type
    ]
  }

  depends_on = [module.service_accounts_safe, null_resource.promote_dc]
}
