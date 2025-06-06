terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "agic-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "agic-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

# Application Gateway Subnet
resource "azurerm_subnet" "agw_subnet" {
  name                 = "agw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# AKS Subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP
resource "azurerm_public_ip" "agw_pip" {
  name                = "agic-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                = "Standard"
}

# Application Gateway
resource "azurerm_application_gateway" "agw" {
  name                = "agic"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.agw_subnet.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.agw_pip.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                 = 80
    protocol             = "Http"
    request_timeout      = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name            = "http-port"
    protocol                      = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                 = "Basic"
    http_listener_name        = "http-listener"
    backend_address_pool_name = "backend-pool"
    backend_http_settings_name = "http-settings"
    priority                  = 1
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "agic-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "agic"
  kubernetes_version  = "1.27.7"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2s_v3"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    Environment = "Production"
  }
}

# AGIC Helm Release
resource "helm_release" "agic" {
  name       = "agic"
  repository = "https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/"
  chart      = "ingress-azure"
  namespace  = "kube-system"

  set {
    name  = "appgw.name"
    value = azurerm_application_gateway.agw.name
  }

  set {
    name  = "appgw.resourceGroup"
    value = azurerm_resource_group.rg.name
  }

  set {
    name  = "appgw.subscriptionId"
    value = data.azurerm_subscription.current.subscription_id
  }

  set {
    name  = "appgw.usePrivateIP"
    value = "false"
  }

  set {
    name  = "armAuth.type"
    value = "servicePrincipal"
  }

  set {
    name  = "armAuth.identityResourceID"
    value = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  }

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_application_gateway.agw
  ]
}

# Get current subscription
data "azurerm_subscription" "current" {} 