output "bootstrap_public_ip" {
  value = var.private ? null : azurerm_public_ip.bootstrap_public_ip_v4[0].ip_address
}
