terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "vmss-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vmss-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# VMSS Subnet
resource "azurerm_subnet" "vmss_subnet" {
  name                 = "vmss-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "vmss_nsg" {
  name                = "vmss-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-ssh"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Subnet NSG Association
resource "azurerm_subnet_network_security_group_association" "vmss_nsg_association" {
  subnet_id                 = azurerm_subnet.vmss_subnet.id
  network_security_group_id = azurerm_network_security_group.vmss_nsg.id
}

# Public IP
resource "azurerm_public_ip" "vmss_pip" {
  name                = "vmss-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                = "Standard"
}

# Load Balancer
resource "azurerm_lb" "vmss_lb" {
  name                = "vmss-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.vmss_pip.id
  }
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "vmss_pool" {
  name            = "vmss-pool"
  loadbalancer_id = azurerm_lb.vmss_lb.id
}

# Health Probe
resource "azurerm_lb_probe" "vmss_probe" {
  name            = "vmss-probe"
  loadbalancer_id = azurerm_lb.vmss_lb.id
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

# Load Balancing Rule
resource "azurerm_lb_rule" "vmss_rule" {
  name                           = "vmss-rule"
  loadbalancer_id               = azurerm_lb.vmss_lb.id
  frontend_ip_configuration_name = "frontend-ip"
  protocol                      = "Tcp"
  frontend_port                 = 80
  backend_port                  = 80
  backend_address_pool_ids      = [azurerm_lb_backend_address_pool.vmss_pool.id]
  probe_id                      = azurerm_lb_probe.vmss_probe.id
}

# Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                = "Standard_F2"
  instances          = 2
  admin_username     = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "primary"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                             = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.vmss_pool.id]
    }
  }

  automatic_instance_repair {
    enabled = true
  }

  automatic_os_upgrade_policy {
    disable_automatic_rollback  = true
    enable_automatic_os_upgrade = true
  }

  rolling_upgrade_policy {
    max_batch_instance_percent             = 20
    max_unhealthy_instance_percent         = 20
    max_unhealthy_upgraded_instance_percent = 20
    pause_time_between_batches            = "PT0S"
  }
} 