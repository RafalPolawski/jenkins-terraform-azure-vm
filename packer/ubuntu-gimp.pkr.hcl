# File: /packer/ubuntu-gimp.pkr.hcl
# packer build -var-file=credentials.pkrvars.hcl ubuntu-gimp.pkr.hcl
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

variable "tenant_id" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

source "azure-arm" "ubuntu-gimp" {
  tenant_id        = var.tenant_id
  subscription_id  = var.subscription_id
  client_id        = var.client_id
  client_secret    = var.client_secret
  
  managed_image_resource_group_name = "packer-images-rg"
  managed_image_name                = "ubuntu-gimp-gui"
  location                          = "West Europe"

  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "ubuntu-24_04-lts"
  image_sku       = "server"

  vm_size = "Standard_B1s"

  temp_resource_group_name          = "packer-temp-rg"
}

build {
  sources = ["source.azure-arm.ubuntu-gimp"]

  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt update",
      "sudo add-apt-repository universe -y",
      "sudo apt update",
      "sudo apt install -y xfce4 xfce4-goodies xrdp gimp",
      "sudo systemctl enable xrdp",
      "sudo systemctl start xrdp",
      "echo xfce4-session > ~/.xsession",
      "sudo systemctl restart xrdp"
    ]
  }
}
