data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}
data "azurerm_subscriptions" "available" {
  display_name_prefix = var.subscriptions_prefix
}

data "http" "ipinfo" {
  url = "https://ipinfo.io"
}

resource "azurerm_storage_account" "storage-account" {
  name                              = var.storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_tier                      = "Standard"
  account_kind                      = "StorageV2"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = concat(tolist(var.whitelist_ips), [jsondecode(data.http.ipinfo.response_body).ip]) // add your ip for later steps
  }

  identity {
    type = "SystemAssigned"
  }

  sas_policy {
    expiration_period = "90.00:00:00"
    expiration_action = "Log"
  }

  lifecycle {
    ignore_changes = [customer_managed_key]
  }
}

locals {
  keyvault_resource_group = var.keyvault_resource_group != null ? var.keyvault_resource_group : var.resource_group_name
}

data "azurerm_key_vault" "kv" {
  name                = var.keyvault_name
  resource_group_name = local.keyvault_resource_group
}

resource "azurerm_key_vault_access_policy" "storage" {
  depends_on = [
    data.azurerm_client_config.current,
    data.azurerm_key_vault.kv,
    azurerm_storage_account.storage-account
  ]
  key_vault_id = data.azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_storage_account.storage-account.identity[0].principal_id

  secret_permissions = ["Get"]
  key_permissions = [
    "Get",
    "UnwrapKey",
    "WrapKey"
  ]
}

resource "azurerm_role_definition" "storage-key-manager" {
  count             = var.create_roles ? 1 : 0
  depends_on        = [data.azurerm_key_vault.kv]
  name              = "${var.subscriptions_prefix}-encryption-key-manager"
  scope             = data.azurerm_subscription.current.id
  assignable_scopes = [for s in data.azurerm_subscriptions.available.subscriptions : s.id]
  # scope       = data.azurerm_subscription.current.id
  description = "This role provides the minimum neccessary permissions for managing encryption keys. As done by storage accounts using customer-managed keys."

  permissions {
    data_actions = [
      "Microsoft.KeyVault/vaults/secrets/getSecret/action",
      "Microsoft.KeyVault/vaults/keys/read",
      "Microsoft.KeyVault/vaults/keys/wrap/action",
      "Microsoft.KeyVault/vaults/keys/unwrap/action"
    ]
  }
}

resource "azurerm_role_assignment" "key-manager-assignment" {
  depends_on = [
    data.azurerm_key_vault.kv,
    azurerm_storage_account.storage-account,
    azurerm_role_definition.storage-key-manager
  ]
  scope                = data.azurerm_key_vault.kv.id
  principal_id         = azurerm_storage_account.storage-account.identity[0].principal_id
  role_definition_name = azurerm_role_definition.storage-key-manager.name
  # role_definition_id   = azurerm_role_definition.storage-key-manager.role_definition_resource_id
}

resource "azurerm_key_vault_key" "key" {
  depends_on = [
    azurerm_storage_account.storage-account,
    data.azurerm_key_vault.kv,
    azurerm_key_vault_access_policy.storage,
    azurerm_role_assignment.key-manager-assignment
  ]
  name         = "${var.storage_account_name}-encryption-key"
  key_vault_id = data.azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
  ]
}

resource "azurerm_storage_account_customer_managed_key" "encryption-key" {
  depends_on = [
    azurerm_storage_account.storage-account,
    data.azurerm_key_vault.kv,
    azurerm_key_vault_key.key
  ]
  storage_account_id = azurerm_storage_account.storage-account.id
  key_vault_id       = data.azurerm_key_vault.kv.id
  key_name           = azurerm_key_vault_key.key.name
}

resource "azurerm_storage_container" "container" {
  depends_on           = [azurerm_storage_account.storage-account]
  name                 = "tfstate"
  storage_account_name = azurerm_storage_account.storage-account.name
  # storage_account_id    = azurerm_storage_account.storage-account.id
  container_access_type = "private" # ie. no anonymous access
}

# TODO: check that this role is actually being assigned
data "azurerm_role_definition" "blob-contributor" {
  # https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor
  role_definition_id = "ba92f5b4-2d11-453d-a403-e96b0029c9fe"
}

data "azurerm_user_assigned_identity" "identity" {
  resource_group_name = var.resource_group_name
  name                = var.managed_identity_name
}

resource "azurerm_role_assignment" "blob-contributor" {
  depends_on = [
    azurerm_storage_container.container,
    data.azurerm_role_definition.blob-contributor
  ]
  scope                = azurerm_storage_container.container.resource_manager_id
  principal_type       = "ServicePrincipal"
  principal_id         = data.azurerm_user_assigned_identity.identity.principal_id
  role_definition_name = data.azurerm_role_definition.blob-contributor.name
  # role_definition_id = data.azurerm_role_definition.blob-contributor.id

  lifecycle {
    # name is an autogenerated guid, will create a new one on every apply unless it's ignored
    ignore_changes = [
      name
    ]
  }
}

resource "azurerm_management_lock" "delete-lock" {
  depends_on = [
    azurerm_storage_account.storage-account,
    azurerm_role_definition.storage-key-manager
  ]
  name       = "no-delete"
  lock_level = "CanNotDelete"
  scope      = azurerm_storage_account.storage-account.id
  notes      = "Prevent deletion of terraform state"
}

data "github_repository" "repo" {
  full_name = "${var.github_org}/${var.github_repository}"
}

resource "github_actions_secret" "storage-account" {
  depends_on = [
    azurerm_storage_account.storage-account,
    data.github_repository.repo
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "STATE_STORAGE_ACCOUNT"
  plaintext_value = azurerm_storage_account.storage-account.name
}

resource "github_actions_secret" "resource-group" {
  depends_on = [
    azurerm_storage_account.storage-account,
    data.github_repository.repo
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "STATE_RESOURCE_GROUP"
  plaintext_value = azurerm_storage_account.storage-account.resource_group_name
}

resource "github_actions_secret" "container" {
  depends_on = [
    azurerm_storage_container.container,
    data.github_repository.repo
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "STATE_CONTAINER_NAME"
  plaintext_value = azurerm_storage_container.container.name
}

resource "github_actions_secret" "statefile" {
  depends_on      = [data.github_repository.repo]
  repository      = data.github_repository.repo.name
  secret_name     = "STATE_FILE"
  plaintext_value = "terraform.tfstate"
}
