terraform {
  cloud {
    organization = "adyavanapalli"
    workspaces {
      name = "Fishtest"
    }
  }
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}
