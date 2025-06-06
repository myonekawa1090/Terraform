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
  name     = "azure-firewall-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "azure-firewall-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# AzureFirewallSubnet
resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall_pip" {
  name                = "azure-firewall-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Azure Firewall
resource "azurerm_firewall" "firewall" {
  name                = "azure-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name           = "AZFW_VNet"
  sku_tier           = "Standard"

  ip_configuration {
    name                 = "firewall-ip-config"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# Firewall Network Rule Collection
resource "azurerm_firewall_network_rule_collection" "network_rules" {
  name                = "azure-firewall-network-rules"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "allow-http"
    source_addresses      = ["*"]
    destination_ports     = ["80"]
    destination_addresses = ["*"]
    protocols             = ["TCP"]
  }

  rule {
    name                  = "allow-https"
    source_addresses      = ["*"]
    destination_ports     = ["443"]
    destination_addresses = ["*"]
    protocols             = ["TCP"]
  }
}

# Firewall Application Rule Collection
resource "azurerm_firewall_application_rule_collection" "app_rules" {
  name                = "azure-firewall-app-rules"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name             = "allow-microsoft"
    source_addresses = ["*"]
    target_fqdns     = ["*.microsoft.com", "*.windows.net"]
    protocol {
      port = "443"
      type = "Https"
    }
  }
} 