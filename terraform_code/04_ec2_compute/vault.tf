# =====================================================================
# CyberArk vaulting of each system's LOCAL credential
#
# Two safes are created via the shared safe module:
#   - MH-Win-Local-Admin : the local Administrator password of each Windows
#     box. The password is EC2-generated and decrypted here with rsadecrypt()
#     using the Conjur-vaulted EC2 key pair PEM. Platform MH-Win-Local.
#   - MH-Linux-SSH-Root  : the SSH key for the Linux box. This stores the
#     existing shared mh-west-key PEM (from Conjur) as a STATIC reference
#     credential — it is NOT CyberArk-managed/rotated (rotation would break
#     every other instance that shares this key). Platform MH-SSH-Root.
# =====================================================================

module "win_local_admin_safe" {
  source         = "../modules/idira/safe"
  safe_name      = var.win_local_admin_safe_name
  description    = "Windows local Administrator accounts (raw EC2 instances)"
  retention_days = var.win_local_admin_safe_retention_days
  members        = var.win_local_admin_safe_members
}

module "linux_ssh_root_safe" {
  source         = "../modules/idira/safe"
  safe_name      = var.linux_ssh_root_safe_name
  description    = "Linux SSH root keys (raw EC2 instances)"
  retention_days = var.linux_ssh_root_safe_retention_days
  members        = var.linux_ssh_root_safe_members
}

# ---------------------------------------------------------------------
# Windows local Administrator — one account per Windows instance
# ---------------------------------------------------------------------
locals {
  windows_hosts = {
    (var.dc_hostname) = {
      password_data = aws_instance.dc.password_data
      address       = var.dc1_private_ip
    }
    (var.windows_connector_hostname) = {
      password_data = aws_instance.connector.password_data
      address       = var.connector_1_private_ip
    }
    (var.windows_target_hostname) = {
      password_data = aws_instance.windows_target.password_data
      address       = var.windows_target_1_private_ip
    }
  }

  linux_hosts = {
    (var.linux_target_1_hostname) = {
      address = var.linux_target_1_private_ip
    }
  }
}

resource "idsec_pcloud_account" "windows_local_admin" {
  for_each = local.windows_hosts

  platform_id = var.win_local_platform_id
  username    = "Administrator"
  address     = each.value.address
  secret      = rsadecrypt(each.value.password_data, data.conjur_secret.aws_pem_key.value)
  safe_name   = module.win_local_admin_safe.safe_name
  name        = "${each.key}-local-admin"

  lifecycle {
    ignore_changes = [
      secret,                      # CPM rotates the password after initial creation
      name,                        # Idira manages naming
      address,                     # cannot be modified on existing accounts
      secret_type,                 # Computed by Idira
      platform_account_properties, # Platform-specific settings
    ]
  }
}

# ---------------------------------------------------------------------
# Linux SSH root key — static reference credential (the shared PEM)
# ---------------------------------------------------------------------
resource "idsec_pcloud_account" "linux_ssh_root" {
  for_each = local.linux_hosts

  platform_id = var.lin_ssh_platform_id
  username    = var.linux_vault_username
  address     = each.value.address
  secret      = data.conjur_secret.aws_pem_key.value # shared EC2 key pair PEM
  safe_name   = module.linux_ssh_root_safe.safe_name
  name        = "${each.key}-ssh-root"

  lifecycle {
    ignore_changes = [
      secret,
      name,
      address,
      secret_type,
      platform_account_properties,
    ]
  }
}
