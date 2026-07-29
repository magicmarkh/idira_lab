# =====================================================================
# Vault the automation user's AWS access key in CyberArk
#
# Creates a dedicated safe, adds members, and stores the bootstrap AWS
# access key (created by the iam_users module) as a CyberArk account.
#
# ROTATION: CyberArk owns rotation of this account. The account's
# `username` (access key ID) and `secret` are marked ignore_changes so
# re-applies never revert the CPM-rotated credential. See the handoff
# note in iam_users/main.tf for the post-apply `terraform state rm` step.
# =====================================================================

# ---------------------------------------------------------------------
# Safe for the automation AWS access key
# ---------------------------------------------------------------------
resource "idsec_pcloud_safe" "automation" {
  safe_name                = var.automation_safe_name
  description              = "AWS access key for the ${var.automation_iam_username} automation user"
  number_of_days_retention = 7
  auto_purge_enabled       = false
  olac_enabled             = false
  location                 = "\\"
}

# ---------------------------------------------------------------------
# Safe members
# ---------------------------------------------------------------------
resource "idsec_pcloud_safe_member" "members" {
  for_each = var.automation_safe_members

  safe_id                    = idsec_pcloud_safe.automation.safe_id
  member_name                = each.value.member_name
  member_type                = each.value.member_type
  search_in                  = try(each.value.search_in, null)
  membership_expiration_date = try(each.value.membership_expiration_date, null)
  permission_set             = each.value.permission_set
}

# ---------------------------------------------------------------------
# AWS access key account
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "automation" {
  platform_id = var.automation_account_platform_id
  username    = module.create_automation_user.access_key_id
  address     = data.aws_caller_identity.current.account_id
  secret      = module.create_automation_user.secret_access_key
  safe_name   = idsec_pcloud_safe.automation.safe_name
  name        = var.automation_account_name

  # CyberArk owns rotation. Ignore the fields the CPM changes on rotation
  # (username/secret) plus the CyberArk-computed/immutable fields.
  lifecycle {
    ignore_changes = [
      username,                    # access key ID changes on CPM rotation
      secret,                      # secret changes on CPM rotation
      address,                     # cannot be modified on existing accounts
      account_id,                  # computed by CyberArk
      created_time,                # computed by CyberArk
      category_modification_time,  # computed by CyberArk
      platform_account_properties, # managed by CyberArk platform
      secret_type,                 # computed field
      status                       # computed field
    ]
  }

  depends_on = [
    idsec_pcloud_safe.automation,
    idsec_pcloud_safe_member.members
  ]
}
