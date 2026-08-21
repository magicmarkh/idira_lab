# =====================================================================
# Kind (Kubernetes-in-Docker) node
#
# Unlike the four RAW instances in instances.tf, this box IS configured:
# the module runs ansible/playbooks/setup_kind_node.yml via a local-exec
# provisioner to stand up a Kind cluster, and pushes an SSH public key to
# the host via SIA (idsec_sia_ssh_public_key).
#
# PREREQUISITES on the machine running `terraform apply`:
#   - ansible installed (the provisioner shells out to ansible-playbook)
#   - network reachability to var.kind_node_private_ip (private subnet, no
#     public IP) — i.e. run from the VPC/VPN, not a laptop off-network.
#
# The SWA (Secure Workload Access) layer inside the module is gated by
# enable_swa_workloads and stays off until you have the SWA chart
# coordinates + enrollment token.
# =====================================================================
module "kind_node" {
  source = "./ec2_instances/kind_node"

  linux_ami_id             = local.linux_ami_id
  instance_type            = var.kind_node_instance_type
  private_subnet_id        = data.terraform_remote_state.foundation.outputs.private_subnet_id
  linux_security_group_ids = data.terraform_remote_state.foundation.outputs.ssh_internal_flat_sg_id
  key_name                 = local.key_name

  kind_node_private_ip = var.kind_node_private_ip
  kind_node_hostname   = var.kind_node_hostname

  team_name        = var.team_name
  asset_owner_name = var.asset_owner_name
  iScheduler       = var.iScheduler

  # Vaulted EC2 key pair PEM (from Conjur) — used by the module for Ansible SSH.
  private_key_contents = data.conjur_secret.aws_pem_key.value
}
