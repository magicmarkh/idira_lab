# =====================================================================
# KEY PAIR
# =====================================================================
output "key_name" {
  description = "Name of the SSH key pair (generated/vaulted in 02_security)"
  value       = data.terraform_remote_state.security.outputs.key_name
}

# =====================================================================
# INSTANCES
# =====================================================================
output "dc_instance_id" {
  description = "ID of the Domain Controller instance"
  value       = aws_instance.dc.id
}

output "connector_instance_id" {
  description = "ID of the Windows connector instance"
  value       = aws_instance.connector.id
}

output "windows_target_instance_id" {
  description = "ID of the Windows target instance"
  value       = aws_instance.windows_target.id
}

output "linux_target_instance_id" {
  description = "ID of the Linux target instance"
  value       = aws_instance.linux_target.id
}

output "instance_private_ips" {
  description = "Private IPs of all four instances, keyed by role"
  value = {
    dc             = aws_instance.dc.private_ip
    connector      = aws_instance.connector.private_ip
    windows_target = aws_instance.windows_target.private_ip
    linux_target   = aws_instance.linux_target.private_ip
  }
}

# =====================================================================
# VAULTING
# =====================================================================
output "win_local_admin_safe_name" {
  description = "Safe holding the Windows local Administrator accounts"
  value       = module.win_local_admin_safe.safe_name
}

output "linux_ssh_root_safe_name" {
  description = "Safe holding the Linux SSH root key"
  value       = module.linux_ssh_root_safe.safe_name
}

output "windows_local_admin_account_names" {
  description = "Vaulted Windows local Administrator account names"
  value       = [for a in idsec_pcloud_account.windows_local_admin : a.name]
}

output "linux_ssh_root_account_names" {
  description = "Vaulted Linux SSH root account names"
  value       = [for a in idsec_pcloud_account.linux_ssh_root : a.name]
}

# =====================================================================
# AMIs
# =====================================================================
output "amazon_linux_ami_id" {
  description = "ID of the Amazon Linux AMI being used"
  value       = local.linux_ami_id
}

output "windows_ami_id" {
  description = "ID of the Windows Server 2022 AMI being used"
  value       = local.windows_ami_id
}
