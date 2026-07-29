data "aws_caller_identity" "current" {}

# =====================================================================
# REMOTE STATE - Foundation Layer
# =====================================================================
data "terraform_remote_state" "foundation" {
  backend = "local"

  config = {
    path = "../01_foundation/terraform.tfstate"
  }
}

# =====================================================================
# IAM ROLES
# =====================================================================
module "ec2_tf_automation_role" {
  source                      = "./iam_roles/ec2_tf_automation_role"
  s3_bucket_arn               = data.terraform_remote_state.foundation.outputs.bucket_arn
  ec2_tf_automation_role_name = var.ec2_tf_automation_role_name
}

# =====================================================================
# IAM USERS
# =====================================================================
module "create_automation_user" {
  source = "./iam_users"

  iam_username  = var.automation_iam_username
  iam_user_path = var.automation_iam_user_path

  tags = {
    Owner       = var.asset_owner_name
    Team        = var.team_name
    Environment = "lab"
  }
}
