# File /terraform/modules/vm/outputs.tf
output "vm_name" {
  description = "Nazwa utworzonej maszyny wirtualnej"
  value       = lower(var.os_type) == "linux" ? azurerm_linux_virtual_machine.linux_vm[0].name : azurerm_windows_virtual_machine.windows_vm[0].name
}

output "vm_admin_username" {
  description = "Nazwa użytkownika administratora"
  value       = var.admin_username
}

output "vm_admin_password" {
  description = "Hasło administratora (tylko dla Windows)"
  value       = var.admin_password
  sensitive   = true
}

output "vm_ssh_public_key" {
  description = "Klucz publiczny SSH (tylko dla Linux)"
  value       = var.ssh_public_key
}