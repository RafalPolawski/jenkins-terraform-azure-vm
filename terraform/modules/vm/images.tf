# Plik: terraform/modules/vm/images.tf
# Definicje i mapowania dostępnych obrazów maszyn wirtualnych (VM).

locals {
  # Mapowanie aliasów obrazów Linux z Azure Marketplace na ich pełne dane (publisher, offer, sku, version).
  default_linux_images = {
    "Ubuntu:22.04-lts-gen2" = { publisher = "Canonical", offer = "0001-com-ubuntu-server-jammy", sku = "22_04-lts-gen2", version = "latest" }
    "Ubuntu:20.04-lts-gen2" = { publisher = "Canonical", offer = "0001-com-ubuntu-server-focal", sku = "20_04-lts-gen2", version = "latest" }
    "Debian:11-gen2"        = { publisher = "Debian", offer = "debian-11", sku = "11-gen2", version = "latest" }
  }

  # Mapowanie aliasów obrazów Windows z Azure Marketplace na ich pełne dane.
  default_windows_images = {
    "WindowsServer:2022-datacenter-smalldisk" = { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2022-datacenter-azure-edition", version = "latest" }
    "WindowsServer:2019-datacenter-smalldisk" = { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter", version = "latest" }
    "WindowsServer:2016-datacenter-smalldisk" = { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2016-Datacenter", version = "latest" }
  }

  # Lista nazw niestandardowych obrazów Windows (znajdujących się w `var.custom_image_rg_name`).
  custom_windows_images = ["windows10-pro"]

  # Lista nazw niestandardowych obrazów Linux (znajdujących się w `var.custom_image_rg_name`).
  custom_linux_images = ["ubuntu-2404-lts-xfce-xrdp"]

  # Połączona lista wszystkich nazw obrazów niestandardowych.
  all_custom_images = concat(local.custom_linux_images, local.custom_windows_images)

  # Połączona mapa wszystkich aliasów obrazów domyślnych (Marketplace).
  all_default_images = merge(local.default_linux_images, local.default_windows_images)
}
