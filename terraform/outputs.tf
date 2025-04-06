# File: /terraform/outputs.tf
# Definicja outputów - eksport informacji o infrastrukturze
output "public_ip" {
  description = "Publiczny adres IP maszyny wirtualnej (dostęp z Internetu)"
  value       = module.network.public_ip  # Eksport adresu z modułu network
}

output "vm_credentials" {
  description = "Wrażliwe dane logowania do VM (uwidocznione w stanie Terraform)"
  value = {
    resource_group = module.resource_group.resource_group_name
    vm_name        = module.vm.vm_name
    public_ip      = module.network.public_ip
    username       = var.admin_username
    password       = var.admin_password
  }
  sensitive = true  # Ukrywanie wartości w logach i CLI
}