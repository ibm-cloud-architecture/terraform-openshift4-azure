output "module_completed" {
  value = join(",", list(azurerm_virtual_machine.bootstrap.id))
}