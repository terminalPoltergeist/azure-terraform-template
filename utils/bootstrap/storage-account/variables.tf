variable "storage_account_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "managed_identity_name" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "github_org" {
  type = string
}

variable "keyvault_name" {
  type = string
}

variable "keyvault_resource_group" {
  type        = string
  description = "The resource group the key vault is in. If not provided, uses var.resource_group_name"
  nullable    = true
  default     = null
}

variable "whitelist_ips" {
  type = set(string)
}

variable "create_roles" {
  type        = bool
  description = "Should we create custom roles? This can only be done once and should then be set to false."
}

variable "subscriptions_prefix" {
  type        = string
  description = "Subscription name prefix to include in role definition assignable scopes."
}
