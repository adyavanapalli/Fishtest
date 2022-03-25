output "ssh_command" {
  value = "ssh ${var.username}@${azurerm_public_ip.public_ip.ip_address}"
}
