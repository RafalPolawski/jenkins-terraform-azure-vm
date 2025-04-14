# File: terraform/modules/resource_group/outputs.tf
# Wartości wyjściowe modułu grupy zasobów.

output "resource_group_name" {
  description = "Nazwa utworzonej grupy zasobów."
  value       = azurerm_resource_group.this.name
}

output "location" {
  description = "Lokalizacja (region Azure) utworzonej grupy zasobów."
  value       = azurerm_resource_group.this.location
}
