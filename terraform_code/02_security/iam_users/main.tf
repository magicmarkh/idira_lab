# =====================================================================
# IAM User
# =====================================================================
resource "aws_iam_user" "this" {
  name = var.iam_username
  path = var.iam_user_path

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )
}

# =====================================================================
# IAM Access Key - Bootstrap key
# =====================================================================
# Terraform creates this key ONCE so the secret can be captured and stored
# in the Idira safe (AWS only returns the secret at creation time).
#
# ROTATION HANDOFF: Idira owns rotation of this account. Rotation deletes
# this key and creates a new one, which would otherwise make Terraform
# regenerate it on the next apply. After the first successful apply:
#
#   1. Run scripts/handoff_automation_key.sh, which does:
#        terraform state rm 'module.create_automation_user.aws_iam_access_key.this'
#   2. Set create_bootstrap_access_key = false (count -> 0) so later applies
#      (e.g. adding the SSM policy) never recreate or destroy the key.
#
# Because the key is count-gated, once it is out of state and the toggle is
# false there is nothing in config to reconcile — Idira fully owns it.
# =====================================================================
resource "aws_iam_access_key" "this" {
  count = var.create_bootstrap_access_key ? 1 : 0
  user  = aws_iam_user.this.name
}
