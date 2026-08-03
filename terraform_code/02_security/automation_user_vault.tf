# =====================================================================
# Vault the automation user's AWS access key in Idira
#
# Creates a dedicated safe, adds members, and stores the bootstrap AWS
# access key (created by the iam_users module) as a Idira account.
#
# ROTATION: Idira owns rotation of this account. On rotation the CPM
# issues a new access key ID (the `AWSAccessKeyID` platform property) and
# secret; the IAM `username` is stable. The rotated fields are marked
# ignore_changes so re-applies never revert the CPM-rotated credential.
# See the handoff note in iam_users/main.tf for the post-apply
# `terraform state rm` step.
# =====================================================================

# ---------------------------------------------------------------------
# Safe (+ members) for the automation AWS access key
#
# Uses the shared unprotected safe module. Nothing in 02_security needs
# destroy protection today; use ../modules/idira/safe_protected for
# safes that must survive `terraform destroy`.
# ---------------------------------------------------------------------
module "safe" {
  source = "../modules/idira/safe"

  safe_name      = var.automation_safe_name
  description    = "AWS access key storage"
  retention_days = 7
  members        = var.automation_safe_members
}

# ---------------------------------------------------------------------
# AWS access key account
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "automation" {
  platform_id = var.automation_account_platform_id
  username    = module.create_automation_user.iam_user_name
  address     = data.aws_caller_identity.current.account_id
  # secret / AWSAccessKeyID come from the bootstrap key on the initial build.
  # Once the key is handed off to Idira (create_bootstrap_access_key = false),
  # the module outputs are null, so fall back to a placeholder. This is safe:
  # both fields are in ignore_changes below, so the CPM-rotated values on the
  # existing account are never reverted.
  secret    = coalesce(module.create_automation_user.secret_access_key, "cpm-managed")
  safe_name = module.safe.safe_name
  name      = var.automation_account_name

  # The AWS Access Keys platform requires the access key ID as a mandatory
  # platform property.
  platform_account_properties = {
    AWSAccessKeyID = coalesce(module.create_automation_user.access_key_id, "cpm-managed")
    AWSAccountID   = data.aws_caller_identity.current.account_id
  }

  # Idira (CPM) owns rotation. The access key ID (AWSAccessKeyID property)
  # and secret change on rotation; the IAM username does not. Ignore the
  # rotated and immutable fields so re-applies never revert them.
  lifecycle {
    ignore_changes = [
      secret,                      # rotated by the CPM
      platform_account_properties, # AWSAccessKeyID rotated by the CPM
      address,                     # cannot be modified on existing accounts
      secret_type                  # set server-side
    ]
  }

  depends_on = [module.safe]
}
