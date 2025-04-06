# File: /terraform/providers.tf
# Konfiguracja dostawców i wersji Terraform
terraform {
  required_version = ">= 1.10.5"  # Minimalna wersja Terraform

  required_providers {
    random = {
      source  = "hashicorp/random"  # Provider do generowania losowych wartości
      version = "3.6.3"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"  # Konfiguracja cloud-init
      version = "2.3.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"  # Oficjalny provider Azure
      version = "4.3.0"
    }
  }
}

# Konfiguracja providera Azure z zachowaniem bezpieczeństwa
provider "azurerm" {
  features {
    resource_group {
      # Zezwolenie na usuwanie grupy z zasobami (dla celów szkoleniowych)
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      # Automatyczne usuwanie dysku OS przy usuwaniu VM
      delete_os_disk_on_deletion = true
    }
  }
  subscription_id = var.subscription_id  # ID subskrypcji z zmiennych
}