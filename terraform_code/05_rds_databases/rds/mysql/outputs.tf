output "mysql_generated_password" {
  value     = random_password.mysql_admin_password.result
  sensitive = true
}

output "mysql_address" {
  description = "Hostname of the MySQL instance (no port)"
  value       = aws_db_instance.mysql.address
}

output "mysql_username" {
  description = "Master username of the MySQL instance"
  value       = aws_db_instance.mysql.username
}