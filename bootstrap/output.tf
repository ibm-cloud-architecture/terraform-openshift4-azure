output "bootstrap_public_ip" {
  value = var.bootstrap_completed ? null : var.private ? null : azurerm_public_ip.bootstrap_public_ip[0].ip_address
}
