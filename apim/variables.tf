variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "japaneast"
}

variable "apim_name" {
  description = "Name of the API Management instance"
  type        = string
}

variable "publisher_name" {
  description = "Name of the API Management publisher"
  type        = string
}

variable "publisher_email" {
  description = "Email address of the API Management publisher"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the API Management instance"
  type        = string
  default     = "Developer_1"
} 