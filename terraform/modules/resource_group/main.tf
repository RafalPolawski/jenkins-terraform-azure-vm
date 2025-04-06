# File: /terraform/modules/resource_group/main.tf

# Best Practice: Jedna grupa zasobów na środowisko/użytkownika
resource "azurerm_resource_group" "this" {
  name     = "student-${var.user_id}-rg"  # Unikalna nazwa z prefixem
  location = var.location  # Dziedziczenie regionu z zmiennych
  tags     = var.tags  # Meta-dane dla zarządzania i kosztów
}

# Eksport nazwy grupy dla zależnych modułów
output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

# Eksport regionu aby zapewnić spójność w całej infrastrukturze
output "location" {
  value = azurerm_resource_group.this.location
}