terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.117.0"
    }
  }
}

provider "github" {}
provider "azurerm" {
  features {}
  storage_use_azuread = true
}
