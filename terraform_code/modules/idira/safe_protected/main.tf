resource "idsec_pcloud_safe" "this" {
  safe_name                = var.safe_name
  description              = var.description
  number_of_days_retention = var.retention_days
  auto_purge_enabled       = var.auto_purge_enabled
  olac_enabled             = var.olac_enabled
  location                 = var.location

  lifecycle {
    prevent_destroy = true
  }
}

resource "idsec_pcloud_safe_member" "this" {
  for_each = var.members

  safe_id                    = idsec_pcloud_safe.this.safe_id
  member_name                = each.value.member_name
  member_type                = each.value.member_type
  search_in                  = try(each.value.search_in, null)
  membership_expiration_date = try(each.value.membership_expiration_date, null)
  permission_set             = each.value.permission_set
}
