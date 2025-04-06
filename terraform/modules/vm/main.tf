# File: /terraform/modules/vm/main.tf

# Maszyna Linux
resource "azurerm_linux_virtual_machine" "linux_vm" {
  count               = lower(var.os_type) == "linux" ? 1 : 0
  name                = "student-${var.user_id}-linux-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  
  network_interface_ids = [
    var.network_interface_id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  tags = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Warunkowe ustawienie źródła obrazu
  dynamic "source_image_reference" {
    for_each = contains(local.custom_linux_images, var.image_name) ? [] : [1]
    content {
      publisher = local.default_linux_images[var.image_name].publisher
      offer     = local.default_linux_images[var.image_name].offer
      sku       = local.default_linux_images[var.image_name].sku
      version   = local.default_linux_images[var.image_name].version
    }
  }

  source_image_id = contains(local.custom_linux_images, var.image_name) ? (
    "/subscriptions/${var.subscription_id}/resourceGroups/packer-images-rg/providers/Microsoft.Compute/images/${var.image_name}"
  ) : null
}

# Maszyna Windows
resource "azurerm_windows_virtual_machine" "windows_vm" {
  count               = lower(var.os_type) == "windows" ? 1 : 0
  name                = "student-${var.user_id}-windows-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  computer_name       = substr("student-${var.user_id}-windows-vm", 0, 15)
  
  network_interface_ids = [
    var.network_interface_id,
  ]

  tags = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Warunkowe ustawienie źródła obrazu
  dynamic "source_image_reference" {
    for_each = contains(local.custom_windows_images, var.image_name) ? [] : [1]
    content {
      publisher = local.default_windows_images[var.image_name].publisher
      offer     = local.default_windows_images[var.image_name].offer
      sku       = local.default_windows_images[var.image_name].sku
      version   = local.default_windows_images[var.image_name].version
    }
  }

  source_image_id = contains(local.custom_windows_images, var.image_name) ? (
    "/subscriptions/${var.subscription_id}/resourceGroups/packer-images-rg/providers/Microsoft.Compute/images/${var.image_name}"
  ) : null
}