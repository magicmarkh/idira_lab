data "aws_caller_identity" "current" {}

data "terraform_remote_state" "ec2_compute" {
  backend = "local"

  config = {
    path = "../../../03_ec2_compute/terraform.tfstate"
  }
}
