# VARIABLE - VM Password
# ─────────────────────────────────────────
variable "admin_password" {
  description = "Password for VM login (azureuser)"
  type        = string
  sensitive   = true                          # hides value in logs
}

# ─────────────────────────────────────────
# RESOURCE GROUP
# Note: Resource group is in West Europe (neutral hub).
# VMs are deployed to Australia East and North Europe via their own location values.
# ─────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "inchararg"
  location = "West Europe"
}

# ─────────────────────────────────────────
# NSG 1 - with SSH rule (Australia East)
# ─────────────────────────────────────────
resource "azurerm_network_security_group" "nsg1" {
  name                = "inch-nsg1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ─────────────────────────────────────────
# NSG 2 - with SSH rule (North Europe)
# ─────────────────────────────────────────
resource "azurerm_network_security_group" "nsg2" {
  name                = "inch-nsg2"
  location            = "northeurope"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ─────────────────────────────────────────
# VNET 1 - for VM1 (Australia East)
# ─────────────────────────────────────────
resource "azurerm_virtual_network" "vnet1" {
  name                = "inch-vnet1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.5.0.0/16"]
}

# ─────────────────────────────────────────
# VNET 2 - for VM2 (North Europe)
# ─────────────────────────────────────────
resource "azurerm_virtual_network" "vnet2" {
  name                = "inch-vnet2"
  location            = "northeurope"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.15.0.0/16"]
}

# ─────────────────────────────────────────
# SUBNET 1 - inside VNet1
# ─────────────────────────────────────────
resource "azurerm_subnet" "subnet1" {
  name                 = "inch-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.5.1.0/24"]
}

# ─────────────────────────────────────────
# SUBNET 2 - inside VNet2
# ─────────────────────────────────────────
resource "azurerm_subnet" "subnet2" {
  name                 = "inch-subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.15.1.0/24"]
}

# ─────────────────────────────────────────
# PUBLIC IP - VM1 (Australia East)
# ─────────────────────────────────────────
resource "azurerm_public_ip" "pip1" {
  name                = "inchpip1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# PUBLIC IP - VM2 (North Europe)
# ─────────────────────────────────────────
resource "azurerm_public_ip" "pip2" {
  name                = "inchpip2"
  location            = "northeurope"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# NIC 1 - VM1 with public IP (Australia East)
# ─────────────────────────────────────────
resource "azurerm_network_interface" "nic1" {
  name                = "inch-nic1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip1.id
  }
}

# ─────────────────────────────────────────
# NIC 2 - VM2 with public IP (North Europe)
# ─────────────────────────────────────────
resource "azurerm_network_interface" "nic2" {
  name                = "inch-nic2"
  location            = "northeurope"
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip2.id
  }
}

# ─────────────────────────────────────────
# NSG1 → NIC1 Association
# ─────────────────────────────────────────
resource "azurerm_network_interface_security_group_association" "nic-nsg-1" {
  network_interface_id      = azurerm_network_interface.nic1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

# ─────────────────────────────────────────
# NSG2 → NIC2 Association
# ─────────────────────────────────────────
resource "azurerm_network_interface_security_group_association" "nic-nsg-2" {
  network_interface_id      = azurerm_network_interface.nic2.id
  network_security_group_id = azurerm_network_security_group.nsg2.id
}

# ─────────────────────────────────────────
# VM 1 - Australia East | 4 vCPU (Standard_D4ads_v5)
# ─────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "inch-vm1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "australiaeast"
  size                = "Standard_D4ads_v5"             # 4 vCPU, 16 GB RAM

  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic1.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ─────────────────────────────────────────
# VM 2 - North Europe | 4 vCPU (Standard_D4ads_v5)
# ─────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "inch-vm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "northeurope"
  size                = "Standard_D4ads_v5"             # 4 vCPU, 16 GB RAM

  admin_username                  = "azureuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic2.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ─────────────────────────────────────────
# VNET PEERING - Bidirectional (cross-region)
# ─────────────────────────────────────────
resource "azurerm_virtual_network_peering" "peer-1" {
  name                      = "vnet1tovnet2"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id = azurerm_virtual_network.vnet2.id
}

resource "azurerm_virtual_network_peering" "peer-2" {
  name                      = "vnet2tovnet1"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id = azurerm_virtual_network.vnet1.id
}
