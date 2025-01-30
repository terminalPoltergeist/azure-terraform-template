resource "azurerm_management_lock" "lock" {
  for_each = var.resource_ids

  name       = "TF-RO-Lock"
  scope      = each.key
  lock_level = "ReadOnly"
  notes      = "This lock is managed by a Terraform project."
}

