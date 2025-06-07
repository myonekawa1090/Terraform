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

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create API Management instance
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email

  sku_name = var.sku_name

  protocols {
    enable_http2 = true
  }

  security {
    enable_backend_ssl30  = false
  }
}

# Create Echo API
resource "azurerm_api_management_api" "echo_api" {
  name                = "echo-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Echo API"
  path                = "echo"
  protocols           = ["https"]
  subscription_required = false

  import {
    content_format = "swagger-json"
    content_value  = file("${path.module}/swagger.json")
  }
}

# Create API Policy
resource "azurerm_api_management_api_policy" "echo_policy" {
  api_name            = azurerm_api_management_api.echo_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <set-backend-service base-url="https://httpbin.org" />
    <rewrite-uri template="/get" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
    <set-header name="X-Response-Time" exists-action="override">
      <value>@(context.Response.Headers.GetValueOrDefault("X-Response-Time","0"))</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
} 