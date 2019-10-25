output "module_completed" {
  value = join(",",
    azurerm_virtual_machine.node.*.id,
    azurerm_network_interface_backend_address_pool_association.node_association.*.id
  )
}

output "vm_id" {
  value = azurerm_virtual_machine.node.0.id
}
