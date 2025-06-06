output "appgw_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.appgw_pip.ip_address
}

output "vm_private_ips" {
  description = "Private IP addresses of the backend VMs"
  value       = [for vm in azurerm_linux_virtual_machine.vm : vm.private_ip_address]
} 