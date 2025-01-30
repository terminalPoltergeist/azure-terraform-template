terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.117.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}
