variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to grant access to"
  type        = string
  # Example: "arn:aws:s3:::my-tf-state-bucket"
}

variable "ec2_tf_automation_role_name" {
  description = "Name of the IAM role for EC2 Terraform automation"
  type        = string
  # Example: "my-role-name"
}
