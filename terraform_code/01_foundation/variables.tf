# ===========================
# Common Variables
# ===========================
variable "asset_owner_name" {
  description = "Name of the human that the cloud team can contact with questions"
  type        = string
  # Example: "jane.doe@example.com"
}

variable "region" {
  description = "AWS cloud region for the deployment"
  type        = string
  default     = "us-west-2"
}

variable "team_name" {
  description = "Cloud naming identifier (used as a prefix for resource names and the S3 bucket)"
  type        = string
  default     = "idira-lab"
}

# ===========================
# VPC Variables
# ===========================
variable "private_subnet_az" {
  description = "AWS identifier for the private subnet AZ"
  type        = string
  default     = "us-west-2b"
}

variable "public_subnet_az" {
  description = "AWS identifier for the public subnet AZ"
  type        = string
  default     = "us-west-2a"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for your public subnet"
  type        = string
  default     = "192.168.50.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for your private subnet"
  type        = string
  default     = "192.168.20.0/24"
}

variable "domain_name" {
  description = "Name of the domain to join connectors to"
  type        = string
  # Example: "idira.lab"
}

variable "dc1_private_ip" {
  description = "Private IP of DC1 (used as DNS server IP)"
  type        = string
  # Example: "192.168.20.10"
}

# ===========================
# State / S3 Bucket
# ===========================
variable "state_bucket_name" {
  description = "Name of the S3 bucket to create. Doubles as the shared Terraform state store consumed by all downstream layers."
  type        = string
  default     = "mh-tf-west-lab"
}

# ===========================
# State Bucket Access
# ===========================
# The mh-tf-west-lab bucket is the shared Terraform state store. Its bucket
# policy denies any request that is neither from one of these public IPs nor
# through the VPC's S3 gateway endpoint. Expand this list to grant more IPs
# (e.g. add the NAT gateway EIP for in-VPC-over-NAT access, or a teammate's IP),
# then re-apply this layer.
variable "state_allowed_ips" {
  description = "Public IP CIDRs allowed to reach the Terraform state bucket. Expandable."
  type        = list(string)
  default     = ["134.238.168.126/32"]
}

# ===========================
# Conjur Variables
# ===========================
variable "conjur_appliance_url" {
  description = "URL of the Conjur appliance"
  type        = string
  default     = ""
  # Example: "https://conjur.idira.lab/api"
}

variable "conjur_account" {
  description = "Conjur account name"
  type        = string
  default     = "conjur"
}

variable "conjur_login" {
  description = "Conjur login name (host identity for API key auth)"
  type        = string
  default     = ""
  # Example: "host/data/aws/idira-lab-terraform"
}

variable "conjur_api_key" {
  description = "Conjur API key for the specified login"
  type        = string
  sensitive   = true
  default     = ""
  # Example: "2x8y1a3b4c5d6e7f8g9h0i1j2k3l4m5n" (do not commit real values)
}

variable "conjur_aws_access_key_path" {
  description = "Conjur secret path for AWS Access Key ID"
  type        = string
  default     = ""
  # Example: "data/aws/idira-lab/access_key_id"
}

variable "conjur_aws_secret_key_path" {
  description = "Conjur secret path for AWS Secret Access Key"
  type        = string
  default     = ""
  # Example: "data/aws/idira-lab/secret_access_key"
}

variable "conjur_authn_type" {
  description = "Conjur auth method: 'api' for API key (laptop), 'iam' for AWS IAM (EC2)"
  type        = string
  default     = "api"
  validation {
    condition     = contains(["api", "iam"], var.conjur_authn_type)
    error_message = "conjur_authn_type must be 'api' or 'iam'."
  }
}

variable "conjur_service_id" {
  description = "Conjur authn-iam service ID (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
  # Example: "prod"
}

variable "conjur_host_id" {
  description = "Conjur host identity for IAM auth (required when conjur_authn_type = 'iam')"
  type        = string
  default     = ""
  # Example: "123456789012/idira-lab-ec2-role"
}
