# =====================================================================
# Conjur Data Sources - Idira Identity service user (for the idsec provider)
# =====================================================================
data "conjur_secret" "identity_client_id" {
  name = var.conjur_identity_client_id_path
}

data "conjur_secret" "identity_client_secret" {
  name = var.conjur_identity_client_secret_path
}

# =====================================================================
# Conjur Data Sources - AWS credentials
# =====================================================================

data "conjur_secret" "aws_access_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_access_key_path
}

data "conjur_secret" "aws_secret_key" {
  count = var.conjur_authn_type == "api" ? 1 : 0
  name  = var.conjur_aws_secret_key_path
}

# =====================================================================
# Conjur Data Sources - MSSQL AD domain-join account
# =====================================================================
# The RDS SQL Server self-managed AD join reads its credentials from AWS
# Secrets Manager (it cannot read Conjur directly). We pull the domain-join
# service account here and bridge it into an ASM secret (see mssql_domain_secret.tf).
# Only fetched when the MSSQL domain join is enabled.
data "conjur_secret" "domain_join_username" {
  count = var.mssql_domain_join_enabled ? 1 : 0
  name  = var.conjur_domain_join_username_path
}

data "conjur_secret" "domain_join_password" {
  count = var.mssql_domain_join_enabled ? 1 : 0
  name  = var.conjur_domain_join_password_path
}
