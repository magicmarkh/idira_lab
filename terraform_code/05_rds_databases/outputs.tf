# =====================================================================
# DB SUBNET GROUP OUTPUTS
# =====================================================================
output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = module.db_subnet_group.db_subnet_group_name
}

# =====================================================================
# RDS DATABASE OUTPUTS
# =====================================================================
output "postgresql_generated_password" {
  description = "Generated master password for the PostgreSQL instance"
  value       = module.postgresql.postgresql_generated_password
  sensitive   = true
}

output "mssql_endpoint" {
  description = "MSSQL (SQL Server Express) connection endpoint"
  value       = module.mssql.mssql_endpoint
}

output "mssql_generated_password" {
  description = "Generated master password for the MSSQL instance"
  value       = module.mssql.mssql_generated_password
  sensitive   = true
}

# =====================================================================
# VAULTING OUTPUTS
# =====================================================================
output "postgresql_safe_name" {
  description = "Safe holding the PostgreSQL master credential"
  value       = module.postgresql_safe.safe_name
}

output "postgresql_vaulted_account_name" {
  description = "Vaulted PostgreSQL master account name"
  value       = idsec_pcloud_account.postgresql_master.name
}

output "mssql_safe_name" {
  description = "Safe holding the MSSQL master credential"
  value       = module.mssql_safe.safe_name
}

output "mssql_vaulted_account_name" {
  description = "Vaulted MSSQL master account name"
  value       = idsec_pcloud_account.mssql_master.name
}
