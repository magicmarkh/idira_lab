# ===========================
# Connector Fleet Outputs
# ===========================
output "connector_count" {
  description = "Number of connectors deployed"
  value       = var.connector_count
}

output "connector_instance_ids" {
  description = "EC2 instance IDs of the connector hosts"
  value       = aws_instance.connector[*].id
}

output "connector_private_ips" {
  description = "Private IPs of the connector hosts"
  value       = aws_instance.connector[*].private_ip
}

output "connector_pool_id" {
  description = "ID of the connector pool the connectors joined (from 03_idira_config/connector_pools)"
  value       = data.terraform_remote_state.connector_pools.outputs.connector_manager_pool_id
}
