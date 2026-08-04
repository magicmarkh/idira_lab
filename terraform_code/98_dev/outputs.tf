# ===========================
# EC2 Instance Outputs
# ===========================
output "instance_id" {
  description = "ID of the mh_dev instance"
  value       = aws_instance.mh_dev.id
}

output "instance_private_ip" {
  description = "Private IP address of the mh_dev instance"
  value       = aws_instance.mh_dev.private_ip
}
