# Idira Connectors Module

Creates EC2 instances that run Idira connector software. These connectors integrate the lab environment with external Idira services for credential management.

## Usage
```hcl
module "cyberark_connectors" {
  source  = "./modules/infrastructure/ec2_instances/cyberark_connectors"
  subnet_id = module.vpc.private_subnet_id
}
```
Grant the attached IAM role only the permissions required for the Idira connector to operate, following the principle of least privilege.
