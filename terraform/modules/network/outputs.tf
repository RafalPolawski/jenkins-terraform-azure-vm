# File: terraform/modules/network/outputs.tf
# Wartości wyjściowe modułu sieciowego, udostępniane innym modułom lub głównemu plikowi.

output "network_interface_id" {
  description = "ID utworzonego interfejsu sieciowego (NIC)."
  value       = azurerm_network_interface.nic.id
}

output "public_ip" {
  description = "Publiczny adres IP przypisany do interfejsu sieciowego VM."
  value       = azurerm_public_ip.vm_ip.ip_address
  sensitive   = true # Adres IP jest traktowany jako dana wrażliwa.
}
