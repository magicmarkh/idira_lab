# ===========================
# IAM Role Outputs
# ===========================
output "ec2_tf_automation_instance_profile_name" {
  description = "Name of the EC2 Terraform automation instance profile"
  value       = module.ec2_tf_automation_role.instance_profile_name
}

output "ec2_tf_automation_instance_profile_arn" {
  description = "ARN of the EC2 Terraform automation instance profile"
  value       = module.ec2_tf_automation_role.instance_profile_arn
}

output "ec2_tf_automation_role_arn" {
  description = "ARN of the EC2 Terraform automation IAM role"
  value       = module.ec2_tf_automation_role.role_arn
}

output "ec2_tf_automation_role_name" {
  description = "Name of the EC2 Terraform automation IAM role"
  value       = module.ec2_tf_automation_role.role_name
}

# =====================================================================
# IAM User Outputs
# =====================================================================
output "automation_user_name" {
  description = "Name of the automation IAM user"
  value       = module.create_automation_user.iam_user_name
}

output "automation_user_arn" {
  description = "ARN of the automation IAM user"
  value       = module.create_automation_user.iam_user_arn
}

# =====================================================================
# Idira Vaulting Outputs
# =====================================================================
output "automation_safe_name" {
  description = "Name of the Idira safe holding the automation AWS access key"
  value       = module.safe.safe_name
}

output "automation_account_id" {
  description = "Idira account ID for the vaulted automation AWS access key"
  value       = idsec_pcloud_account.automation.account_id
}

# =====================================================================
# Key Pair Outputs
# =====================================================================
output "key_name" {
  description = "Name of the AWS EC2 SSH key pair (consumed by 04_ec2_compute via remote state)"
  value       = aws_key_pair.server.key_name
}

output "keypair_safe_name" {
  description = "Name of the Idira safe holding the AWS EC2 private key"
  value       = module.keypair_safe.safe_name
}

output "keypair_account_id" {
  description = "Idira account ID for the vaulted AWS EC2 private key"
  value       = idsec_pcloud_account.keypair.account_id
}
