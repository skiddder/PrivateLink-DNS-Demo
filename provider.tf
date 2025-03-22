terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.23"
    }
  }
}

provider "azurerm" {
  features {
  }
  resource_provider_registrations = "none"
  subscription_id                 = "<subscription_id>"
  environment                     = "public"
  use_msi                         = false
  use_cli                         = true
  use_oidc                        = false
}
