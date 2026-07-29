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
# in the CyberArk safe (AWS only returns the secret at creation time).
#
# ROTATION HANDOFF: CyberArk owns rotation of this account. Rotation deletes
# this key and creates a new one, which would otherwise make Terraform
# regenerate it on the next apply. After the first successful apply, remove
# this resource from state so CyberArk fully owns the credential:
#
#   terraform state rm 'module.create_automation_user.aws_iam_access_key.this'
# =====================================================================
resource "aws_iam_access_key" "this" {
  user = aws_iam_user.this.name
}
