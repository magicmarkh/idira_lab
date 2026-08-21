# =====================================================================
# MSSQL self-managed AD domain-join secret (Conjur -> AWS Secrets Manager)
#
# RDS SQL Server joins a self-managed Active Directory using credentials it
# reads from AWS Secrets Manager — it cannot read Conjur. So we take the
# domain-join service account out of Conjur (see data.tf) and materialize it
# into an ASM secret in the RDS region, in the exact JSON shape RDS requires:
#   { "CUSTOMER_MANAGED_ACTIVE_DIRECTORY_USERNAME": "...",
#     "CUSTOMER_MANAGED_ACTIVE_DIRECTORY_PASSWORD": "..." }
# The ARN is then handed to the mssql module as domain_auth_secret_arn.
#
# Gated by var.mssql_domain_join_enabled: leave it false to deploy a
# standalone SQL Server Express with no AD join.
# =====================================================================
resource "aws_secretsmanager_secret" "mssql_domain_join" {
  count       = var.mssql_domain_join_enabled ? 1 : 0
  name        = "${var.team_name}-mssql-domain-joiner"
  description = "Self-managed AD domain-join credentials for RDS SQL Server (sourced from Conjur)"
}

resource "aws_secretsmanager_secret_version" "mssql_domain_join" {
  count     = var.mssql_domain_join_enabled ? 1 : 0
  secret_id = aws_secretsmanager_secret.mssql_domain_join[0].id
  secret_string = jsonencode({
    CUSTOMER_MANAGED_ACTIVE_DIRECTORY_USERNAME = data.conjur_secret.domain_join_username[0].value
    CUSTOMER_MANAGED_ACTIVE_DIRECTORY_PASSWORD = data.conjur_secret.domain_join_password[0].value
  })
}

# RDS reads the secret as the rds.amazonaws.com service principal; a resource
# policy is required for the self-managed AD integration to access it.
resource "aws_secretsmanager_secret_policy" "mssql_domain_join" {
  count      = var.mssql_domain_join_enabled ? 1 : 0
  secret_arn = aws_secretsmanager_secret.mssql_domain_join[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowRDSSelfManagedADJoin"
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "secretsmanager:GetSecretValue"
      Resource  = "*"
    }]
  })
}
