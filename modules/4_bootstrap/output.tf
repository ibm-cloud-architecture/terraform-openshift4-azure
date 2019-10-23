output "module_completed" {
  value = join(",", azurerm_virtual_machine.bootstrap.*.id)
}
