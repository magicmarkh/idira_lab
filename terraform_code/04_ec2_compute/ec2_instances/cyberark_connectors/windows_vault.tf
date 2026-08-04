# =====================================================================
# Improvement #1 — Vault the connector's local Administrator in Idira
#
# The Windows connector's local Administrator password is EC2-generated and
# decrypted in Terraform via the Conjur-vaulted PEM (local.admin_password in
# windows.tf). We store it in a dedicated Idira safe so the credential is
# managed rather than discarded. Simple safe + account (no Conjur Sync member).
# =====================================================================

resource "idsec_pcloud_safe" "connector_safe" {
  safe_name                = var.connector_safe_name
  description              = var.connector_safe_description
  number_of_days_retention = var.connector_safe_retention_days

  # Create the safe only once the instance exists (its password drives the account).
  depends_on = [aws_instance.connector_1]
}

resource "idsec_pcloud_account" "connector_local_admin" {
  platform_id = var.connector_local_admin_platform_id
  username    = "Administrator"
  address     = "${var.windows_connector_hostname}.${var.domain_name}"
  secret      = local.admin_password # EC2-generated, decrypted via the vaulted PEM
  safe_name   = idsec_pcloud_safe.connector_safe.safe_name
  name        = "${var.windows_connector_hostname}-local-admin"

  # Vault after the box is joined so the address (hostname.domain) is resolvable.
  depends_on = [idsec_pcloud_safe.connector_safe, null_resource.join_domain]

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
