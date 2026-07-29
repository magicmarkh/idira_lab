variable "region" {}

variable "asset_owner_name" {}

variable "vpc_state_file_path" {
  description = "Path to networking.tfstate to read VPC outputs"
  type        = string
  default     = "./terraform.tfstate"
}

variable "bucket_name" {}


