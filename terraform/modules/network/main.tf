# File: /terraform/modules/network/main.tf

# Virtual Network - podstawa sieciowa
resource "azurerm_virtual_network" "vnet" {
  name                = "student-${var.user_id}-vnet"  # Unikalna nazwa
  address_space       = ["10.0.0.0/16"]  # Prywatna przestrzeń adresowa
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Podsieć dla zasobów
resource "azurerm_subnet" "subnet" {
  name                 = "student-${var.user_id}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]  # /24 dla prostoty zarządzania
}

# Network Security Group (NSG) - reguły firewall
resource "azurerm_network_security_group" "nsg" {
  name                = "student-${var.user_id}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-ssh-rdp-vnc"
    priority                   = 1001  # Niższy priorytet = wyższy priorytet wykonania
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"    # Dowolny port źródłowy
    destination_port_ranges    = ["22", "3389", "5900"]  # SSH, RDP, VNC
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Publiczne IP z przypisaniem statycznym
resource "azurerm_public_ip" "vm_ip" {
  name                = "student-${var.user_id}-vm-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"  # Lepsze dla DNS
  sku                 = "Standard"  # Wsparcie dla stref dostępności
}

# Interfejs sieciowy z przypisaniem IP
resource "azurerm_network_interface" "nic" {
  name                = "student-${var.user_id}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"  # Azure zarządza adresacją
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

# Powiązanie NSG z interfejsem
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Outputy dla integracji z modułami
output "network_interface_id" {
  value = azurerm_network_interface.nic.id  # ID dla modułu VM
}

output "public_ip" {
  value = azurerm_public_ip.vm_ip.ip_address  # Publiczny adres dla outputów
}