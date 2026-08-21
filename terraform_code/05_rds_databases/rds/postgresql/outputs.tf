output "postgresql_generated_password" {
  value     = random_password.postgresql_admin_password.result
  sensitive = true
}

output "postgresql_address" {
  description = "Hostname of the PostgreSQL instance (no port)"
  value       = aws_db_instance.postgresql.address
}

output "postgresql_endpoint" {
  description = "Connection endpoint of the PostgreSQL instance (host:port)"
  value       = aws_db_instance.postgresql.endpoint
}

output "postgresql_port" {
  description = "Port of the PostgreSQL instance"
  value       = aws_db_instance.postgresql.port
}

output "postgresql_username" {
  description = "Master username of the PostgreSQL instance"
  value       = aws_db_instance.postgresql.username
}