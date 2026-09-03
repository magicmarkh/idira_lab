# Create a CyberArk Privilege Cloud safe. Identical to secure/main.tf — the only
# difference between the two examples is where the Identity service-user
# credential comes from (see provider.tf).
resource "idsec_pcloud_safe" "main" {
  safe_name                = var.safe_name
  description              = var.safe_description
  number_of_days_retention = var.number_of_days_retention
}

# Grant the admin user full permissions on the safe.
resource "idsec_pcloud_safe_member" "admin" {
  safe_id        = idsec_pcloud_safe.main.safe_id
  member_name    = var.safe_admin_member
  member_type    = "User"
  search_in      = "CyberArk Cloud Directory"
  permission_set = "full"
}

output "safe_id" {
  description = "ID of the created safe"
  value       = idsec_pcloud_safe.main.safe_id
}

output "safe_name" {
  description = "Name of the created safe"
  value       = idsec_pcloud_safe.main.safe_name
}
