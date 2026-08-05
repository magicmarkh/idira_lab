data "aws_caller_identity" "current" {}

module "vpc" {
  source              = "./networking/vpc"
  region              = var.region
  asset_owner_name    = var.asset_owner_name
  team_name           = var.team_name
  private_subnet_az   = var.private_subnet_az
  public_subnet_az    = var.public_subnet_az
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  domain_name         = var.domain_name
  dns_server_ip       = var.dc1_private_ip
}

module "s3_bucket" {
  source           = "./s3_bucket"
  asset_owner_name = var.asset_owner_name
  bucket_name      = var.state_bucket_name

  # This bucket is also the shared Terraform state store. Restrict access to an
  # expandable list of public IPs plus the VPC's S3 gateway endpoint (for in-VPC
  # runs). The endpoint already exists in the vpc module.
  state_allowed_ips     = var.state_allowed_ips
  state_vpc_endpoint_id = module.vpc.s3_vpc_endpoint_id
}

module "security_groups" {
  source              = "./networking/security_groups"
  asset_owner_name    = var.asset_owner_name
  vpc_id              = module.vpc.vpc_id
  team_name           = var.team_name
  internal_subnets    = ["${var.public_subnet_cidr}", "${var.private_subnet_cidr}"]
  private_subnet_cidr = var.private_subnet_cidr
  public_subnet_cidr  = var.public_subnet_cidr
}
