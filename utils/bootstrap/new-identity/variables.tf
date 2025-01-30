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
