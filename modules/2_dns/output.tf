output "module_completed" {
  value = "${join(",", list(azurerm_dns_zone.private.id))}"
}
