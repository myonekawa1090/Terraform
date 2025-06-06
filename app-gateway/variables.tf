variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "appgw"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "japaneast"
}