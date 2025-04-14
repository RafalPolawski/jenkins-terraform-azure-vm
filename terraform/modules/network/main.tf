# File: terraform/modules/network/main.tf
# Moduł odpowiedzialny za tworzenie podstawowych zasobów sieciowych dla VM studenta.
# Zawiera: Virtual Network, Subnet, Network Security Group, Public IP, Network Interface.

# Wirtualna sieć (VNet) dla izolacji środowiska studenta.
resource "azurerm_virtual_network" "vnet" {
  name                = "student-${var.user_id}-vnet"
  address_space       = ["10.0.0.0/16"] # Prywatna przestrzeń adresowa dla VNet.
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Podsieć wewnątrz VNet, do której podłączona będzie VM.
resource "azurerm_subnet" "subnet" {
  name                 = "student-${var.user_id}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"] # Zakres adresów IP dla tej podsieci.
}

# Grupa zabezpieczeń sieciowych (NSG) definiująca reguły ruchu przychodzącego i wychodzącego.
resource "azurerm_network_security_group" "nsg" {
  name                = "student-${var.user_id}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Reguła zezwalająca na standardowy ruch przychodzący (SSH, RDP, VNC).
  security_rule {
    name                       = "AllowStandardInbound"
    priority                   = 1001 # Priorytet reguły (niższa liczba = wyższy priorytet).
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389", "5900-5909"] # Porty: SSH, RDP, VNC (zakres)
    source_address_prefixes    = var.allowed_source_ips      # Zezwala na ruch z określonych adresów IP.
    destination_address_prefix = "*"
  }
}

# Publiczny adres IP dla maszyny wirtualnej.
resource "azurerm_public_ip" "vm_ip" {
  name                = "student-${var.user_id}-vm-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  allocation_method   = "Static"   # Statyczny IP, aby adres się nie zmieniał po restarcie VM.
  sku                 = "Standard" # SKU Standard jest zalecane dla większości zastosowań.
}

# Interfejs sieciowy (NIC) dla maszyny wirtualnej.
resource "azurerm_network_interface" "nic" {
  name                = "student-${var.user_id}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id   # Podłącza NIC do zdefiniowanej podsieci.
    private_ip_address_allocation = "Dynamic"                  # Prywatny IP przydzielany dynamicznie z puli podsieci.
    public_ip_address_id          = azurerm_public_ip.vm_ip.id # Przypisuje publiczny IP do NIC.
  }
}

# Powiązanie grupy zabezpieczeń sieciowych (NSG) z interfejsem sieciowym (NIC).
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
