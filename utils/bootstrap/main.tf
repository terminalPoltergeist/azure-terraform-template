module "new-identity" {
  count  = var.create_new_identity ? 1 : 0
  source = "./new-identity"

  resource_group_name       = var.resource_group_name
  managed_identity_name     = var.managed_identity_name
  location                  = var.location
  federated_credential_name = var.federated_credential_name
  github_org                = var.github_org
  github_repository         = var.github_repository
}

module "existing-identity" {
  count  = var.create_new_identity ? 0 : 1
  source = "./existing-identity"

  resource_group_name       = var.resource_group_name
  managed_identity_name     = var.managed_identity_name
  federated_credential_name = var.federated_credential_name
  github_org                = var.github_org
  github_repository         = var.github_repository
}

module "storage-account" {
  depends_on = [
    module.new-identity,
    module.existing-identity
  ]
  count  = var.create_storage_account ? 1 : 0
  source = "./storage-account"

  managed_identity_name   = var.managed_identity_name
  resource_group_name     = var.resource_group_name
  storage_account_name    = var.storage_account_name
  github_repository       = var.github_repository
  github_org              = var.github_org
  location                = var.location
  keyvault_name           = var.keyvault_name
  keyvault_resource_group = var.keyvault_resource_group
  whitelist_ips           = var.storage_account_whitelist_ips
  subscriptions_prefix    = var.subscriptions_prefix
  create_roles            = var.create_roles
}

module "branch-protections" {
  source = "./repository-settings"

  repository = var.github_repository
}
