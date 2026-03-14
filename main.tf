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
# VMs are deployed to Australia East and japan east via their own location values.
# ─────────────────────────────────────────
resource "azurerm_resource_group" "rg" {
  name     = "shivalik-rg"
  location = "West Europe"
}

# ─────────────────────────────────────────
# NSG 1 - with SSH rule (Australia East)
# ─────────────────────────────────────────
resource "azurerm_network_security_group" "nsg1" {
  name                = "shivalik-nsg1"
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
# NSG 2 - with SSH rule (japan east)
# ─────────────────────────────────────────
resource "azurerm_network_security_group" "nsg2" {
  name                = "shivalik-nsg2"
  location            = "japaneast"
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
  name                = "shivalik-vnet1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.5.0.0/16"]
}

# ─────────────────────────────────────────
# VNET 2 - for VM2 (Japan East)
# ─────────────────────────────────────────
resource "azurerm_virtual_network" "vnet2" {
  name                = "shivalik-vnet2"
  location            = "japaneast"
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.15.0.0/16"]
}

# ─────────────────────────────────────────
# SUBNET 1 - inside VNet1
# ─────────────────────────────────────────
resource "azurerm_subnet" "subnet1" {
  name                 = "shivalik-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.5.1.0/24"]
}

# ─────────────────────────────────────────
# SUBNET 2 - inside VNet2
# ─────────────────────────────────────────
resource "azurerm_subnet" "subnet2" {
  name                 = "shivalik-subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.15.1.0/24"]
}

# ─────────────────────────────────────────
# PUBLIC IP - VM1 (Australia East)
# ─────────────────────────────────────────
resource "azurerm_public_ip" "pip1" {
  name                = "shivalikpip1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# PUBLIC IP - VM2 (Japan East)
# ─────────────────────────────────────────
resource "azurerm_public_ip" "pip2" {
  name                = "shivalikpip2"
  location            = "japaneast"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# NIC 1 - VM1 with public IP (Australia East)
# ─────────────────────────────────────────
resource "azurerm_network_interface" "nic1" {
  name                = "shivalik-nic1"
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
# NIC 2 - VM2 with public IP (japan east)
# ─────────────────────────────────────────
resource "azurerm_network_interface" "nic2" {
  name                = "shivalik-nic2"
  location            = "japaneast"
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
  name                = "shivalik-vm1"
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
# VM 2 - japan east | 4 vCPU (Standard_D4ads_v5)
# ─────────────────────────────────────────
resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "shivalik-vm2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "japaneast"
  size                = "Standard_D4s_v3"             # 4 vCPU, 16 GB RAM

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




# ─────────────────────────────────────────
# AGW SUBNET 1 — dedicated for AGW1 (Australia East)
# Must be inside vnet1 (10.5.0.0/16). Uses 10.5.2.0/24.
# Cannot overlap with subnet1 (10.5.1.0/24).
# ─────────────────────────────────────────
resource "azurerm_subnet" "agw_subnet1" {
  name                 = "shivalik-agw-subnet1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.5.2.0/24"]
}

# ─────────────────────────────────────────
# AGW SUBNET 2 — dedicated for AGW2 (Japan East)
# Must be inside vnet2 (10.15.0.0/16). Uses 10.15.2.0/24.
# Cannot overlap with subnet2 (10.15.1.0/24).
# ─────────────────────────────────────────
resource "azurerm_subnet" "agw_subnet2" {
  name                 = "shivalik-agw-subnet2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.15.2.0/24"]
}

# ─────────────────────────────────────────
# PUBLIC IP — AGW1 (Australia East)
# Standard SKU required for Application Gateway v2.
# ─────────────────────────────────────────
resource "azurerm_public_ip" "agw_pip1" {
  name                = "shivalik-agw-pip1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# PUBLIC IP — AGW2 (Japan East)
# ─────────────────────────────────────────
resource "azurerm_public_ip" "agw_pip2" {
  name                = "shivalik-agw-pip2"
  location            = "japaneast"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# ─────────────────────────────────────────
# LOCAL VALUES
# Reusable name strings for AGW components to keep the
# resource blocks readable. These are Terraform-internal only.
# ─────────────────────────────────────────
locals {
  # AGW1 component names
  agw1_fe_ip_config   = "agw1-fe-ip-config"
  agw1_fe_port        = "agw1-fe-port-80"
  agw1_be_pool        = "agw1-be-pool-vm1"
  agw1_be_http_setting = "agw1-be-http-setting"
  agw1_http_listener  = "agw1-http-listener"
  agw1_request_routing = "agw1-request-routing-rule"

  # AGW2 component names
  agw2_fe_ip_config   = "agw2-fe-ip-config"
  agw2_fe_port        = "agw2-fe-port-80"
  agw2_be_pool        = "agw2-be-pool-vm2"
  agw2_be_http_setting = "agw2-be-http-setting"
  agw2_http_listener  = "agw2-http-listener"
  agw2_request_routing = "agw2-request-routing-rule"
}

# ─────────────────────────────────────────
# APPLICATION GATEWAY 1 — Australia East
#
# SKU: Standard_v2 (supports autoscaling, WAF-ready)
# Tier: Standard_v2
# Backend: VM1 private IP (fetched from the VM resource)
# Listener: HTTP on port 80
# ─────────────────────────────────────────
resource "azurerm_application_gateway" "agw1" {
  name                = "shivalik-agw1"
  location            = "australiaeast"
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1                          # fixed capacity = 1 instance (no autoscale)
  }

  # ── Frontend ──────────────────────────
  gateway_ip_configuration {
    name      = "agw1-gateway-ip-config"
    subnet_id = azurerm_subnet.agw_subnet1.id
  }

  frontend_ip_configuration {
    name                 = local.agw1_fe_ip_config
    public_ip_address_id = azurerm_public_ip.agw_pip1.id
  }

  frontend_port {
    name = local.agw1_fe_port
    port = 80
  }

  # ── Backend ───────────────────────────
  # VM1 private IP is sourced directly from the VM resource —
  # no hardcoding needed, Terraform resolves it at plan time.
  backend_address_pool {
    name  = local.agw1_be_pool
    ip_addresses = [azurerm_linux_virtual_machine.vm1.private_ip_address]
  }

  backend_http_settings {
    name                  = local.agw1_be_http_setting
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30           # seconds before AGW closes idle connection
  }

  # ── Routing ───────────────────────────
  http_listener {
    name                           = local.agw1_http_listener
    frontend_ip_configuration_name = local.agw1_fe_ip_config
    frontend_port_name             = local.agw1_fe_port
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.agw1_request_routing
    rule_type                  = "Basic"
    priority                   = 100          # required for Standard_v2
    http_listener_name         = local.agw1_http_listener
    backend_address_pool_name  = local.agw1_be_pool
    backend_http_settings_name = local.agw1_be_http_setting
  }

  depends_on = [
    azurerm_subnet.agw_subnet1,
    azurerm_public_ip.agw_pip1,
    azurerm_linux_virtual_machine.vm1
  ]
}

# ─────────────────────────────────────────
# APPLICATION GATEWAY 2 — Japan East
#
# Identical structure to AGW1, pointed at VM2.
# ─────────────────────────────────────────
resource "azurerm_application_gateway" "agw2" {
  name                = "shivalik-agw2"
  location            = "japaneast"
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  # ── Frontend ──────────────────────────
  gateway_ip_configuration {
    name      = "agw2-gateway-ip-config"
    subnet_id = azurerm_subnet.agw_subnet2.id
  }

  frontend_ip_configuration {
    name                 = local.agw2_fe_ip_config
    public_ip_address_id = azurerm_public_ip.agw_pip2.id
  }

  frontend_port {
    name = local.agw2_fe_port
    port = 80
  }

  # ── Backend ───────────────────────────
  backend_address_pool {
    name         = local.agw2_be_pool
    ip_addresses = [azurerm_linux_virtual_machine.vm2.private_ip_address]
  }

  backend_http_settings {
    name                  = local.agw2_be_http_setting
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  # ── Routing ───────────────────────────
  http_listener {
    name                           = local.agw2_http_listener
    frontend_ip_configuration_name = local.agw2_fe_ip_config
    frontend_port_name             = local.agw2_fe_port
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.agw2_request_routing
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = local.agw2_http_listener
    backend_address_pool_name  = local.agw2_be_pool
    backend_http_settings_name = local.agw2_be_http_setting
  }

  depends_on = [
    azurerm_subnet.agw_subnet2,
    azurerm_public_ip.agw_pip2,
    azurerm_linux_virtual_machine.vm2
  ]
}

# ─────────────────────────────────────────
# NSG RULE — Allow HTTP:80 inbound on VM NICs
#
# The VMs' NSGs currently only allow SSH (port 22).
# The Application Gateway health probes and forwarded traffic
# arrive on port 80, so a new inbound rule is required on both NSGs.
# Without this the AGW backend health check will fail (unhealthy).
# ─────────────────────────────────────────
resource "azurerm_network_security_rule" "allow_http_vm1" {
  name                        = "allow-http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg1.name
}

resource "azurerm_network_security_rule" "allow_http_vm2" {
  name                        = "allow-http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg2.name
}

