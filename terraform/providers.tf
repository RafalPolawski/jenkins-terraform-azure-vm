# File: terraform/providers.tf
# Konfiguracja Terraform i dostawców chmury (Azure).

terraform {
  required_version = ">= 1.1.0" # Wymaga co najmniej wersji Terraform 1.1.0.

  required_providers {
    # Dostawca do generowania losowych wartości, np. nazw.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0" # Używa wersji kompatybilnej z 3.6.0.
    }
    # Główny dostawca do zarządzania zasobami Azure.
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3.0" # Używa wersji kompatybilnej z 4.3.0.
    }
  }
}

provider "azurerm" {
  # Konfiguracja specyficznych zachowań dostawcy AzureRM.
  features {
    resource_group {
      # Umożliwia usunięcie grupy zasobów, nawet jeśli zawiera zasoby.
      # Przydatne w środowiskach tymczasowych/szkoleniowych.
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      # Automatycznie usuwa dysk OS wraz z maszyną wirtualną.
      delete_os_disk_on_deletion = true
    }
  }
  subscription_id = var.subscription_id # ID subskrypcji Azure pobierane ze zmiennej.
}
