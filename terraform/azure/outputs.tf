output "ssh_command" {
  value = "ssh ${var.username}@${data.azurerm_public_ip.public_ip.ip_address}"
}
