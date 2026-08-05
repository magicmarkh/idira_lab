# =====================================================================
# 03_idira_config/safes_and_accounts — repeatable safes + account vaulting
#
# Everything is driven by var.safes and var.accounts (see terraform.tfvars).
# This file is generic — add/remove safes and accounts in tfvars, not here.
# =====================================================================

# ---------------------------------------------------------------------
# SAFES (+ members) — one shared safe module instance per var.safes entry
# ---------------------------------------------------------------------
module "safes" {
  source   = "../../modules/idira/safe"
  for_each = var.safes

  safe_name          = each.value.safe_name
  description        = each.value.description
  retention_days     = each.value.retention_days
  auto_purge_enabled = each.value.auto_purge_enabled
  olac_enabled       = each.value.olac_enabled
  location           = each.value.location
  members            = each.value.members
}

# ---------------------------------------------------------------------
# Resolve each account's target safe name.
# ---------------------------------------------------------------------
locals {
  # safe_key -> created safe name, for accounts landing in a safe from this layer.
  created_safe_names = { for k, m in module.safes : k => m.safe_name }
}

# ---------------------------------------------------------------------
# ACCOUNTS — vaulted into the resolved safe
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "this" {
  for_each = var.accounts

  platform_id = each.value.platform_id
  username    = each.value.username
  address     = each.value.address
  name        = coalesce(each.value.name, "${each.value.username}-${each.value.address}")

  # Prefer safe_key (a safe created in this layer); fall back to an explicit
  # safe_name (a pre-existing safe). lookup() avoids indexing errors when the
  # key is intentionally blank.
  safe_name = each.value.safe_key != "" ? lookup(local.created_safe_names, each.value.safe_key, each.value.safe_name) : each.value.safe_name

  # Literal secret to vault (empty string == no secret set on the account).
  secret = each.value.secret

  platform_account_properties          = each.value.platform_account_properties
  remote_machines                      = length(each.value.remote_machines) > 0 ? each.value.remote_machines : null
  access_restricted_to_remote_machines = length(each.value.remote_machines) > 0

  lifecycle {
    ignore_changes = [
      secret,                      # CPM may rotate after creation; don't fight it
      name,                        # Idira manages naming
      address,                     # cannot be modified on existing accounts
      secret_type,                 # computed by Idira
      platform_account_properties, # platform-specific settings
    ]
  }
}
