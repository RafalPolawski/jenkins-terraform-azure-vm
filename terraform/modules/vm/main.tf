# File: terraform/modules/vm/main.tf
# Główna logika tworzenia maszyny wirtualnej (Linux lub Windows) w Azure.

locals {
  # Sprawdza, czy podana nazwa obrazu (`var.image_name`) znajduje się na liście obrazów niestandardowych.
  is_custom_image = contains(local.all_custom_images, var.image_name)

  # Pobiera dane obrazu z mapy `all_default_images`, jeśli obraz *nie* jest niestandardowy.
  # Używa `try` aby uniknąć błędu, jeśli `var.image_name` nie istnieje w mapie (choć nie powinno się to zdarzyć przy poprawnym użyciu).
  marketplace_image_data = local.is_custom_image ? null : try(local.all_default_images[var.image_name], null)

  # Tworzy mapę tagu `DestroyTimestampUTC` tylko jeśli `var.destroy_timestamp_utc` nie jest pusty.
  # Pozwala to na warunkowe dodanie tagu do zasobów VM.
  destroy_tag = var.destroy_timestamp_utc != "" ? {
    DestroyTimestampUTC = var.destroy_timestamp_utc
  } : {}
}

# Definicja zasobu dla maszyny wirtualnej Linux.
# Tworzona tylko jeśli var.os_type to "linux".
resource "azurerm_linux_virtual_machine" "linux_vm" {
  count = lower(var.os_type) == "linux" ? 1 : 0 # Warunek tworzenia zasobu.

  name                = "student-${var.user_id}-linux-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [
    var.network_interface_id, # Podłącza wcześniej utworzony NIC.
  ]

  # Konfiguracja logowania za pomocą klucza SSH.
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # Łączy tagi wspólne (`var.tags`) z warunkowym tagiem `destroy_tag`.
  tags = merge(
    var.tags,
    local.destroy_tag
  )

  # Konfiguracja dysku systemowego.
  os_disk {
    caching              = "ReadWrite"    # Standardowe ustawienie cache dla dysków OS.
    storage_account_type = "Standard_LRS" # Typ przechowywania (HDD), bardziej ekonomiczny.
  }

  # Określa źródło obrazu - używane dla obrazów z Azure Marketplace.
  # Wypełniane tylko jeśli obraz *nie* jest niestandardowy (`local.is_custom_image == false`).
  source_image_reference {
    publisher = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.publisher
    offer     = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.offer
    sku       = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.sku
    version   = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.version
  }

  # Określa źródło obrazu - używane dla obrazów niestandardowych.
  # Wypełniane tylko jeśli obraz *jest* niestandardowy (`local.is_custom_image == true`).
  source_image_id = local.is_custom_image ? (
    # Konstruuje pełny ID obrazu niestandardowego.
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.custom_image_rg_name}/providers/Microsoft.Compute/images/${var.image_name}"
  ) : null

}

# Definicja zasobu dla maszyny wirtualnej Windows.
# Tworzona tylko jeśli var.os_type to "windows".
resource "azurerm_windows_virtual_machine" "windows_vm" {
  count = lower(var.os_type) == "windows" ? 1 : 0 # Warunek tworzenia zasobu.

  name                = "student-${var.user_id}-windows-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password # Hasło administratora wymagane dla Windows.
  # Nazwa komputera w systemie Windows (max 15 znaków).
  computer_name = substr("win-${var.user_id}", 0, 15)
  network_interface_ids = [
    var.network_interface_id, # Podłącza wcześniej utworzony NIC.
  ]

  # Łączy tagi wspólne (`var.tags`) z warunkowym tagiem `destroy_tag`.
  tags = merge(
    var.tags,
    local.destroy_tag
  )

  # Konfiguracja dysku systemowego.
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" # Typ HDD.
  }

  # Określa źródło obrazu - używane dla obrazów z Azure Marketplace.
  # Wypełniane tylko jeśli obraz *nie* jest niestandardowy.
  source_image_reference {
    publisher = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.publisher
    offer     = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.offer
    sku       = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.sku
    version   = local.is_custom_image || local.marketplace_image_data == null ? null : local.marketplace_image_data.version
  }

  # Określa źródło obrazu - używane dla obrazów niestandardowych.
  # Wypełniane tylko jeśli obraz *jest* niestandardowy.
  source_image_id = local.is_custom_image ? (
    # Konstruuje pełny ID obrazu niestandardowego.
    "/subscriptions/${var.subscription_id}/resourceGroups/${var.custom_image_rg_name}/providers/Microsoft.Compute/images/${var.image_name}"
  ) : null
}
