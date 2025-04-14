# File: terraform/main.tf
# Główny plik orkiestracji modułów, definiujący zasoby poprzez wywołania modułów.

locals {
  # Definiuje wspólne tagi stosowane do wszystkich zasobów dla spójności i zarządzania.
  common_tags = {
    OwnerId   = var.user_id
    CreatedBy = "Terraform-Jenkins"
    Env       = "Training"
    Project   = "Student Labs"
    OsType    = lower(var.os_type) # <-- OsType dla joba czyszczącego (tag wykorzystywany przez zewnętrzne skrypty)
  }
  # Dynamicznie wybiera rozmiar VM na podstawie systemu operacyjnego.
  vm_size = lower(var.os_type) == "linux" ? var.linux_vm_size : var.windows_vm_size
}

# Tworzy grupę zasobów dla środowiska studenta.
module "resource_group" {
  source   = "./modules/resource_group"
  user_id  = var.user_id
  location = var.location
  tags     = local.common_tags
}

# Konfiguruje zasoby sieciowe: VNet, Subnet, NSG, Public IP, NIC.
module "network" {
  source = "./modules/network"

  user_id             = var.user_id
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.location
  tags                = local.common_tags
  allowed_source_ips  = var.allowed_source_ips
}

# Tworzy maszynę wirtualną (Linux lub Windows) z odpowiednią konfiguracją.
module "vm" {
  source = "./modules/vm"

  user_id               = var.user_id
  resource_group_name   = module.resource_group.resource_group_name
  location              = module.resource_group.location
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  os_type               = var.os_type
  ssh_public_key        = var.ssh_public_key
  network_interface_id  = module.network.network_interface_id
  tags                  = local.common_tags
  subscription_id       = var.subscription_id
  image_name            = var.image_name
  vm_size               = local.vm_size # Używa dynamicznie określonego rozmiaru VM.
  custom_image_rg_name  = var.custom_image_rg_name
  destroy_timestamp_utc = var.destroy_timestamp_utc # Przekazuje timestamp dla automatycznego usuwania.
}
