terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial backend config — actual values supplied at `terraform init` time
  # via -backend-config flags (see backend.hcl.example and README.md).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azurerm_client_config" "current" {}
