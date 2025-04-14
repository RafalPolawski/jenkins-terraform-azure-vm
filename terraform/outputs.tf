# File: terraform/outputs.tf
# Definicje głównych wartości wyjściowych infrastruktury.

output "public_ip" {
  description = "Publiczny adres IP maszyny wirtualnej."
  value       = module.network.public_ip
  sensitive   = true # Adres IP jest traktowany jako dana wrażliwa.
}

output "vm_credentials" {
  description = "Dane logowania i informacje identyfikacyjne dla VM."
  value = {
    resource_group = module.resource_group.resource_group_name
    vm_name        = module.vm.vm_name
    public_ip      = module.network.public_ip
    username       = var.admin_username
    # Hasło jest zwracane tylko dla Windows, dla Linux używany jest klucz SSH.
    password = lower(var.os_type) == "windows" ? var.admin_password : null
  }
  sensitive = true # Zawiera potencjalnie wrażliwe dane (hasło, IP).
}

output "vm_admin_username" {
  description = "Nazwa użytkownika administratora VM."
  value       = var.admin_username
  sensitive   = true # Nazwa użytkownika może być uznana za wrażliwą.
}
