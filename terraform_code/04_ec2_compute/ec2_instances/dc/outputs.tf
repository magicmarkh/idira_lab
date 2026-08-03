output "private_ip" {
  description = "Private IP of the domain controller"
  value       = aws_instance.us-ent-east-dc1.private_ip
}

output "instance_id" {
  description = "EC2 instance ID of the domain controller"
  value       = aws_instance.us-ent-east-dc1.id
}

output "domain_join_password" {
  description = "Password of the domain-join service account created in AD (for later vaulting)"
  value       = random_password.domain_join.result
  sensitive   = true
}

# Handle downstream resources can depend on to sequence after promotion completes.
output "promote_complete_id" {
  description = "ID of the time_sleep gate that fires once promotion has settled"
  value       = time_sleep.wait_after_promote.id
}
