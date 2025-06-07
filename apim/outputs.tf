output "apim_id" {
  description = "ID of the API Management instance"
  value       = azurerm_api_management.apim.id
}

output "apim_gateway_url" {
  description = "Gateway URL of the API Management instance"
  value       = azurerm_api_management.apim.gateway_url
}

output "apim_management_url" {
  description = "Management API URL of the API Management instance"
  value       = azurerm_api_management.apim.management_api_url
} 