resource "aws_instance" "kind_node" {
  ami                         = var.linux_ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  associate_public_ip_address = false
  key_name                    = var.key_name
  vpc_security_group_ids      = [var.linux_security_group_ids]
  private_ip                  = var.kind_node_private_ip
  disable_api_termination     = true

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash -xe
    hostnamectl set-hostname "${var.kind_node_hostname}"
  EOF

  tags = {
    Name                 = "${var.team_name}-kind-1"
    I_Owner              = var.asset_owner_name
    I_Purpose            = "Murphys Lab Kind Kubernetes Node"
    CA_iScheduler        = var.iScheduler
    CA_iSchedulerControl = "yes"
  }

  lifecycle {
    ignore_changes  = [tags, ami, user_data]
    prevent_destroy = true
  }
}

# =====================================================================
# CyberArk SSH Public Key: Add public key to Linux system
# =====================================================================
resource "idsec_sia_ssh_public_key" "kind_node_key" {
  target_machine       = aws_instance.kind_node.private_ip
  username             = "ec2-user"
  private_key_contents = var.private_key_contents

  depends_on = [aws_instance.kind_node]
}

# Absolute path to the repo's ansible/ dir (repo_root/ansible). Running the
# provisioners with working_dir set here makes them independent of the CWD
# terraform was invoked from, and lets ansible.cfg (roles_path/host_key_checking)
# apply. path.module is 4 levels below repo root.
locals {
  ansible_dir = abspath("${path.module}/../../../../ansible")
}

resource "null_resource" "setup_kind" {
  depends_on = [aws_instance.kind_node]

  provisioner "local-exec" {
    working_dir = local.ansible_dir
    command     = <<EOT
# Write private key to temp file
KEYFILE=$(mktemp)
echo '${var.private_key_contents}' > "$KEYFILE"
chmod 600 "$KEYFILE"

# Wait for SSH to become available
echo "Waiting for SSH on ${aws_instance.kind_node.private_ip}..."
for i in $(seq 1 30); do
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$KEYFILE" ec2-user@${aws_instance.kind_node.private_ip} "echo ready" && break
  echo "Attempt $i/30 - waiting 10s..."
  sleep 10
done

# Run Ansible playbook (working_dir is repo_root/ansible)
ansible-playbook \
  -i '${aws_instance.kind_node.private_ip},' \
  -e 'ansible_user=ec2-user' \
  --private-key="$KEYFILE" \
  playbooks/setup_kind_node.yml

# Cleanup
rm -f "$KEYFILE"
EOT
  }
}

# =====================================================================
# SWA (Secure Workload Access) layer — installs the SWA agent, builds and
# loads the swa-probe / fetch-secret images, deploys and verifies the probe.
#
# Gated by var.enable_swa_workloads: leave it false until you have the SWA
# agent Helm chart coordinates + enrollment token from your SWA tenant, so a
# plain `03_ec2_compute` apply is unaffected. Re-runs when the token changes.
# =====================================================================
resource "null_resource" "setup_swa_workloads" {
  count      = var.enable_swa_workloads ? 1 : 0
  depends_on = [null_resource.setup_kind]

  triggers = {
    enrollment_token = sha256(var.swa_agent_enrollment_token)
    chart_version    = var.swa_agent_chart_version
  }

  provisioner "local-exec" {
    working_dir = local.ansible_dir
    command     = <<EOT
KEYFILE=$(mktemp)
echo '${var.private_key_contents}' > "$KEYFILE"
chmod 600 "$KEYFILE"

ansible-playbook \
  -i '${aws_instance.kind_node.private_ip},' \
  -e 'ansible_user=ec2-user' \
  -e 'swa_agent_helm_repo_url=${var.swa_agent_helm_repo_url}' \
  -e 'swa_agent_chart=${var.swa_agent_chart}' \
  -e 'swa_agent_chart_version=${var.swa_agent_chart_version}' \
  -e 'swa_agent_enrollment_token=${var.swa_agent_enrollment_token}' \
  --private-key="$KEYFILE" \
  playbooks/setup_swa_workloads.yml

rm -f "$KEYFILE"
EOT
  }
}
