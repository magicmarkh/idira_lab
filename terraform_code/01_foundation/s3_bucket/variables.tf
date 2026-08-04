variable "asset_owner_name" {}

variable "bucket_name" {}

variable "state_allowed_ips" {
  description = "Public IP CIDRs allowed to access the state bucket (e.g. laptop, NAT EIP). Expandable list."
  type        = list(string)
}

variable "state_vpc_endpoint_id" {
  description = "S3 gateway VPC endpoint ID exempted from the IP allowlist so in-VPC hosts can reach state."
  type        = string
}
