data "azurerm_subscription" "subscription" {}

resource "azurerm_user_assigned_identity" "identity" {
  resource_group_name = var.resource_group_name
  name                = var.managed_identity_name
  location            = var.location
}

resource "azurerm_role_assignment" "lock-contributor" {
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
  scope                = data.azurerm_subscription.subscription.id
  role_definition_name = "Locks Contributor"
}

resource "azurerm_federated_identity_credential" "integration_credential" {
  depends_on          = [azurerm_user_assigned_identity.identity]
  name                = "${var.federated_credential_name}-integration"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.identity.id
  subject             = "repo:${var.github_org}/${var.github_repository}:pull_request"
}

resource "azurerm_federated_identity_credential" "deploy_credential" {
  depends_on          = [azurerm_user_assigned_identity.identity]
  name                = "${var.federated_credential_name}-deploy"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.identity.id
  subject             = "repo:${var.github_org}/${var.github_repository}:ref:refs/heads/main"
}

data "github_repository" "repo" {
  full_name = "${var.github_org}/${var.github_repository}"
}

resource "github_actions_secret" "client_id" {
  depends_on = [
    data.github_repository.repo,
    azurerm_user_assigned_identity.identity
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = azurerm_user_assigned_identity.identity.client_id
}

resource "github_actions_secret" "subscription_id" {
  depends_on = [
    data.github_repository.repo,
    data.azurerm_subscription.subscription
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = data.azurerm_subscription.subscription.subscription_id
}

resource "github_actions_secret" "tenant_id" {
  depends_on = [
    data.github_repository.repo,
    azurerm_user_assigned_identity.identity
  ]
  repository      = data.github_repository.repo.name
  secret_name     = "AZURE_TENANT_ID"
  plaintext_value = azurerm_user_assigned_identity.identity.tenant_id
}

resource "azurerm_management_lock" "lock" {
  depends_on = [
    azurerm_user_assigned_identity.identity,
    azurerm_federated_identity_credential.integration_credential,
    azurerm_federated_identity_credential.deploy_credential
  ]
  scope      = azurerm_user_assigned_identity.identity.id
  name       = "TF no delete"
  lock_level = "CanNotDelete"
  notes      = "This identity is used in GithubActions pipelines for authenticating terraform to Azure"
}
