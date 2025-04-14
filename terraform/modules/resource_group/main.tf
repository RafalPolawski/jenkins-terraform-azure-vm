# File: terraform/modules/resource_group/main.tf
# Moduł odpowiedzialny za tworzenie grupy zasobów Azure.

# Definicja zasobu grupy zasobów.
resource "azurerm_resource_group" "this" {
  # Nazwa grupy zasobów tworzona dynamicznie z użyciem user_id dla unikalności.
  name     = "student-${var.user_id}-rg"
  location = var.location
  tags     = var.tags
}
