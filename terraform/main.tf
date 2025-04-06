# File: /terraform/main.tf
# Główna konfiguracja infrastruktury - moduły i tagowanie
locals {
  # Wspólne tagi dla wszystkich zasobów
  common_tags = {
    OwnerId   = var.user_id
    CreatedBy = "Terraform"
    Env       = "Training"
    Project   = "Student Labs"
  }
}

# Moduł grupy zasobów - fundament infrastruktury
module "resource_group" {
  source    = "./modules/resource_group"
  user_id   = var.user_id
  location  = var.location
  tags      = local.common_tags
}

# Moduł sieciowy - konfiguracja sieciowa
module "network" {
  source               = "./modules/network"
  user_id              = var.user_id
  resource_group_name  = module.resource_group.resource_group_name
  location             = module.resource_group.location
  os_type              = var.os_type
}

# Moduł maszyny wirtualnej - główny komponent infrastruktury
module "vm" {
  source                 = "./modules/vm"
  user_id                = var.user_id
  resource_group_name    = module.resource_group.resource_group_name
  location               = module.resource_group.location
  admin_username         = var.admin_username
  admin_password         = var.admin_password
  os_type                = var.os_type
  ssh_public_key         = var.ssh_public_key
  network_interface_id   = module.network.network_interface_id
  tags                   = local.common_tags
  subscription_id        = var.subscription_id
  image_name             = var.image_name
}