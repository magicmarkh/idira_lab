# =====================================================================
# Outputs — keyed by the same local ids used in var.safes / var.accounts
# =====================================================================
output "safe_names" {
  description = "Created safe names, keyed by safe_key"
  value       = { for k, m in module.safes : k => m.safe_name }
}

output "safe_ids" {
  description = "Created safe ids, keyed by safe_key"
  value       = { for k, m in module.safes : k => m.safe_id }
}

output "account_names" {
  description = "Vaulted account display names, keyed by account local id"
  value       = { for k, a in idsec_pcloud_account.this : k => a.name }
}
