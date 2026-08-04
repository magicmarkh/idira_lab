data "aws_caller_identity" "current" {}

# =====================================================================
# REMOTE STATE - Foundation Layer
# =====================================================================
data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/01_foundation.tfstate"
    region = "us-west-2"
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

  create_bootstrap_access_key = var.create_bootstrap_access_key

  tags = {
    Owner       = var.asset_owner_name
    Team        = var.team_name
    Environment = "lab"
  }
}
