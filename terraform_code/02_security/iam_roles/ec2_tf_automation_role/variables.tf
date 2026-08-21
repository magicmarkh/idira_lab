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

variable "domain_join_secret_name_prefix" {
  description = "Name prefix of the ASM secret holding the MSSQL domain-join credentials (05_rds_databases creates it as <team>-mssql-domain-joiner). Used to scope the Secrets Manager policy."
  type        = string
  default     = "mh-west-mssql-domain-joiner"
}
