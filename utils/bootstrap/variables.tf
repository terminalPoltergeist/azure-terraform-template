variable "create_new_identity" {
  type = bool
}

variable "resource_group_name" {
  type = string
}

variable "managed_identity_name" {
  type = string
}

variable "location" {
  type    = string
  default = "northcentralus"
}

variable "federated_credential_name" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "create_storage_account" {
  default = false
}

variable "storage_account_name" {
  type = string
}

variable "keyvault_name" {
  type = string
}

variable "keyvault_resource_group" {
  type     = string
  nullable = true
  default  = null
}

variable "storage_account_whitelist_ips" {
  type = set(string)
}

variable "create_roles" {
  type        = bool
  default     = true
  description = "Should we create custom roles? This can only be done once and should then be set to false."
}

variable "subscriptions_prefix" {
  type        = string
  description = "Subscirption name prefix to include in custom role assignable scopes."
}
