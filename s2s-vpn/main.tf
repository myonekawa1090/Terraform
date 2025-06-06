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

# Azure Side Resources
# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "s2s-vpn-rg"
  location = var.location
}

# Azure Virtual Network
resource "azurerm_virtual_network" "azure_vnet" {
  name                = "s2s-vpn-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Azure Gateway Subnet
resource "azurerm_subnet" "azure_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.azure_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Public IP for VPN Gateway
resource "azurerm_public_ip" "azure_vpn_gateway_pip" {
  name                = "s2s-vpn-gateway-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure VPN Gateway
resource "azurerm_virtual_network_gateway" "azure_vpn_gateway" {
  name                = "s2s-vpn-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.azure_vpn_gateway_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.azure_gateway_subnet.id
  }
}

# On-premises Side Resources
# On-premises Virtual Network
resource "azurerm_virtual_network" "onprem_vnet" {
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["192.168.0.0/16"]
}

# On-premises Gateway Subnet
resource "azurerm_subnet" "onprem_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

# On-premises Public IP for VPN Gateway
resource "azurerm_public_ip" "onprem_vpn_gateway_pip" {
  name                = "onprem-vpn-gateway-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# On-premises VPN Gateway
resource "azurerm_virtual_network_gateway" "onprem_vpn_gateway" {
  name                = "onprem-vpn-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem_vpn_gateway_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem_gateway_subnet.id
  }
}

# Local Network Gateway for Azure side
resource "azurerm_local_network_gateway" "azure_local_gateway" {
  name                = "s2s-vpn-local-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  gateway_address     = azurerm_public_ip.onprem_vpn_gateway_pip.ip_address
  address_space       = [azurerm_virtual_network.onprem_vnet.address_space[0]]
}

# Local Network Gateway for On-premises side
resource "azurerm_local_network_gateway" "onprem_local_gateway" {
  name                = "onprem-local-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  gateway_address     = azurerm_public_ip.azure_vpn_gateway_pip.ip_address
  address_space       = [azurerm_virtual_network.azure_vnet.address_space[0]]
}

# VPN Connection from Azure to On-premises
resource "azurerm_virtual_network_gateway_connection" "azure_to_onprem" {
  name                       = "azure-to-onprem"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.azure_vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.azure_local_gateway.id

  shared_key = var.shared_key
}

# VPN Connection from On-premises to Azure
resource "azurerm_virtual_network_gateway_connection" "onprem_to_azure" {
  name                       = "onprem-to-azure"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem_vpn_gateway.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem_local_gateway.id

  shared_key = var.shared_key
} 