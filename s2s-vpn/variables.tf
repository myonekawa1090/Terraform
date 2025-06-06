variable "location" {
  type        = string
  description = "Azure region"
  default     = "japaneast"
}

variable "shared_key" {
  type        = string
  description = "Shared key for VPN connection"
  sensitive   = true
} 