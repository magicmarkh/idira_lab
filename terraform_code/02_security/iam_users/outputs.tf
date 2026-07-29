# ===========================
# IAM User Outputs
# ===========================
output "iam_user_name" {
  description = "Name of the IAM user"
  value       = aws_iam_user.this.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = aws_iam_user.this.arn
}

output "access_key_id" {
  description = "Access key ID for this user"
  value       = aws_iam_access_key.this.id
}

output "secret_access_key" {
  description = "Secret access key for this user (bootstrap; vaulted in CyberArk)"
  value       = aws_iam_access_key.this.secret
  sensitive   = true
}
