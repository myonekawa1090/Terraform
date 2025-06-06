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
  name     = "load-balancer-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "load-balancer-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Backend Subnet
resource "azurerm_subnet" "backend_subnet" {
  name                 = "backend-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "lb_pip" {
  name                = "load-balancer-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Load Balancer
resource "azurerm_lb" "lb" {
  name                = "load-balancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

# Backend Pool
resource "azurerm_lb_backend_address_pool" "backend_pool" {
  name            = "load-balancer-backend-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Health Probe
resource "azurerm_lb_probe" "health_probe" {
  name            = "load-balancer-health-probe"
  loadbalancer_id = azurerm_lb.lb.id
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

# Load Balancing Rule
resource "azurerm_lb_rule" "lb_rule" {
  name                           = "load-balancer-rule"
  loadbalancer_id               = azurerm_lb.lb.id
  frontend_ip_configuration_name = "frontend-ip"
  protocol                      = "Tcp"
  frontend_port                 = 80
  backend_port                  = 80
  backend_address_pool_ids      = [azurerm_lb_backend_address_pool.backend_pool.id]
  probe_id                      = azurerm_lb_probe.health_probe.id
} 