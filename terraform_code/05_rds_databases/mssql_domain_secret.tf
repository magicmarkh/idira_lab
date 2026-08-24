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
#
# KMS: RDS self-managed AD requires the secret to be encrypted with a
# CUSTOMER-MANAGED KMS key whose key policy grants the rds.amazonaws.com
# service principal decrypt access. The default aws/secretsmanager key can't be
# shared with RDS, so RDS rejects it ("domain authentication secret ARN ...
# must be valid"). We create a dedicated CMK for this below.
# =====================================================================
resource "aws_kms_key" "mssql_domain_join" {
  count                   = var.mssql_domain_join_enabled ? 1 : 0
  description             = "Encrypts the RDS SQL Server self-managed AD domain-join secret"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAdmin"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowRDSToDecrypt"
        Effect    = "Allow"
        Principal = { Service = "rds.amazonaws.com" }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_kms_alias" "mssql_domain_join" {
  count         = var.mssql_domain_join_enabled ? 1 : 0
  name          = "alias/${var.team_name}-mssql-domain-joiner"
  target_key_id = aws_kms_key.mssql_domain_join[0].key_id
}

resource "aws_secretsmanager_secret" "mssql_domain_join" {
  count       = var.mssql_domain_join_enabled ? 1 : 0
  name        = "${var.team_name}-mssql-domain-joiner"
  description = "Self-managed AD domain-join credentials for RDS SQL Server (sourced from Conjur)"
  kms_key_id  = aws_kms_key.mssql_domain_join[0].arn
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
