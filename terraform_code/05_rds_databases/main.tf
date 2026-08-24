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
# DB SUBNET GROUP
# =====================================================================
module "db_subnet_group" {
  source             = "./db_subnet_group"
  team_name          = var.team_name
  private_subnet_ids = [data.terraform_remote_state.foundation.outputs.private_subnet_id, data.terraform_remote_state.foundation.outputs.public_subnet_id]
}

# =====================================================================
# RDS DATABASES
# =====================================================================
module "mysql" {
  source                 = "./rds/mysql"
  iScheduler             = var.iScheduler
  db_subnet_group_name   = module.db_subnet_group.db_subnet_group_name
  asset_owner_name       = var.asset_owner_name
  vpc_security_group_ids = [data.terraform_remote_state.foundation.outputs.mysql_target_sg_id]
}

module "postgresql" {
  source                 = "./rds/postgresql"
  iScheduler             = var.iScheduler
  db_subnet_group_name   = module.db_subnet_group.db_subnet_group_name
  asset_owner_name       = var.asset_owner_name
  vpc_security_group_ids = [data.terraform_remote_state.foundation.outputs.postgresql_target_sg_id]
  team_name              = var.team_name
}

module "mssql" {
  source                 = "./rds/mssql"
  identifier             = "${var.team_name}-mssql"
  iScheduler             = var.iScheduler
  db_subnet_group_name   = module.db_subnet_group.db_subnet_group_name
  asset_owner_name       = var.asset_owner_name
  vpc_security_group_ids = [data.terraform_remote_state.foundation.outputs.mssql_target_sg_id]

  # Self-managed AD domain join. The domain-join account is pulled from Conjur
  # and bridged into AWS Secrets Manager (mssql_domain_secret.tf); when the
  # join is disabled these are null and RDS deploys standalone.
  domain_auth_secret_arn = var.mssql_domain_join_enabled ? aws_secretsmanager_secret.mssql_domain_join[0].arn : null
  domain_fqdn            = var.mssql_domain_join_enabled ? var.mssql_domain_fqdn : null
  domain_ou              = var.mssql_domain_join_enabled ? var.mssql_domain_ou : null

  depends_on = [aws_secretsmanager_secret_version.mssql_domain_join]
}
