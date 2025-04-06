# File: /terraform/modules/vm/images.tf
locals {
  # Obrazy domyślne (z galerii Azure)
  default_linux_images = {
    "Ubuntu:22.04-lts-gen2" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    },
    "Ubuntu:20.04-lts-gen2" = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "20_04-lts"
      version   = "latest"
    },
    "Debian:11-gen2" = {
      publisher = "Debian"
      offer     = "debian-11"
      sku       = "11"
      version   = "latest"
    }
  }
  default_windows_images = {
    "WindowsServer:2022-datacenter-smalldisk" = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-Datacenter"
      version   = "latest"
    },
    "WindowsServer:2019-datacenter-smalldisk" = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2019-Datacenter"
      version   = "latest"
    },
    "WindowsServer:2016-datacenter-smalldisk" = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2016-Datacenter"
      version   = "latest"
    }
  }

  # Obrazy własne
  custom_windows_images = [
    "windows10-edu"
  ]
  custom_linux_images = [
    "ubuntu-gimp-gui"
  ]

  # Pełne listy obrazów (domyślne + własne)
  windows_images = concat(keys(local.default_windows_images), local.custom_windows_images)
  linux_images = concat(keys(local.default_linux_images), local.custom_linux_images)
}