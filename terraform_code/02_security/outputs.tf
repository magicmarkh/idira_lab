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

output "automation_access_key_id" {
  description = "Access key ID for the automation user"
  value       = module.create_automation_user.access_key_id
}

# =====================================================================
# CyberArk Vaulting Outputs
# =====================================================================
output "automation_safe_name" {
  description = "Name of the CyberArk safe holding the automation AWS access key"
  value       = idsec_pcloud_safe.automation.safe_name
}

output "automation_account_id" {
  description = "CyberArk account ID for the vaulted automation AWS access key"
  value       = idsec_pcloud_account.automation.account_id
}
