output "vm1_private_ip" {
  description = "VM1 Private IP (Australia East)"
  value       = azurerm_linux_virtual_machine.vm1.private_ip_address
}

output "vm1_public_ip" {
  description = "VM1 Public IP (Australia East)"
  value       = azurerm_public_ip.pip1.ip_address
}

output "vm2_private_ip" {
  description = "VM2 Private IP (North Europe)"
  value       = azurerm_linux_virtual_machine.vm2.private_ip_address
}

output "vm2_public_ip" {
  description = "VM2 Public IP (North Europe)"
  value       = azurerm_public_ip.pip2.ip_address
}

output "agw1_public_ip" {
  description = "Application Gateway 1 public IP (Australia East) — send HTTP traffic here"
  value       = azurerm_public_ip.agw_pip1.ip_address
}

output "agw2_public_ip" {
  description = "Application Gateway 2 public IP (Japan East) — send HTTP traffic here"
  value       = azurerm_public_ip.agw_pip2.ip_address
}
