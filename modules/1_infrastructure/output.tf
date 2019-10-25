output "resource_group_name" {
  value = "${azurerm_resource_group.openshift.name}"
}

output "controlplane_vnet_id" {
  value = "${azurerm_virtual_network.controlplane.id}"
}

output "worker_vnet_id" {
  value = "${azurerm_virtual_network.worker.id}"
}

output "controlplane_vnet_name" {
  value = azurerm_virtual_network.controlplane.name
}

output "worker_vnet_name" {
  value = azurerm_virtual_network.worker.name
}
output "controlplane_subnet_cidr" {
  value = "${local.controlplane_subnet_cidr}"
}

output "worker_subnet_cidr" {
  value = "${local.worker_subnet_cidr}"
}

output "apps_lb_pip_fqdn" {
  value = "${data.azurerm_public_ip.worker_public_ip.fqdn}"
}

output "cluster_lb_pip_fqdn" {
  value = "${data.azurerm_public_ip.cluster_public_ip.fqdn}"
}

output "internal_lb_ip_address" {
  value = "${azurerm_lb.controlplane_internal.private_ip_address}"
}

output "vnet_id" {
  value = "${azurerm_virtual_network.controlplane.id}"
}

output "master_ip_addresses" {
  value = "${azurerm_network_interface.master.*.private_ip_address}"
}

output "private_ssh_key" {
  value = "${chomp(tls_private_key.installkey.private_key_pem)}"
}

output "public_ssh_key" {
  value = "${chomp(tls_private_key.installkey.public_key_openssh)}"
}

output "storage_account_name" {
  value = "${azurerm_storage_account.ignition.name}"
}

output "storage_container_name" {
  value = "${azurerm_storage_container.ignition.name}"
}

output "storage_account_sas" {
  value = "${data.azurerm_storage_account_sas.ignition.sas}"
}

output "user_assigned_identity_id" {
  value = "${azurerm_user_assigned_identity.main.id}"
}

output "public_subnet_id" {
  value = "${azurerm_subnet.master_subnet.id}"
}
output "node_subnet_ids" {
  value = "${azurerm_subnet.node_subnet.id}"
}

output "external_lb_controlplane_pool_id" {
  value = "${azurerm_lb_backend_address_pool.external_lb_controlplane_pool.id}"
}

output "worker_lb_backend_pool_id" {
  value = "${azurerm_lb_backend_address_pool.worker_public_lb_pool.id}"
}

output "internal_lb_backend_pool_id" {
  value = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
}

output "boot_diag_blob_endpoint" {
  value = "${azurerm_storage_account.bootdiag.primary_blob_endpoint}"
}

output "master_nsg_name" {
  value = "${azurerm_network_security_group.master.name}"
}

output "bootstrap_network_interface_id" {
  value = "${azurerm_network_interface.bootstrap.id}"
}

output "master_network_interface_id" {
  value = "${azurerm_network_interface.master.*.id}"
}

output "worker_network_interface_id" {
  value = "${azurerm_network_interface.worker.*.id}"
}

output "azure_storage_azurefile_name" {
  value = "${azurerm_storage_share.azurefile.name}"
}

output "internal_lb_controlplane_pool_id" {
  value = azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id
}
output "module_completed" {
  value = "${join(",",
    "${list(azurerm_resource_group.openshift.id)}",
    "${list(azurerm_virtual_network.controlplane.id)}",
    "${list(azurerm_virtual_network.worker.id)}",
    "${list(azurerm_subnet.master_subnet.id)}",
    "${list(azurerm_subnet.node_subnet.id)}",
    # "${list(azurerm_subnet_network_security_group_association.master.id)}",
    # "${list(azurerm_subnet_network_security_group_association.worker.id)}",
    # "${azurerm_network_interface_backend_address_pool_association.master.*.id}",
    # "${azurerm_network_interface_backend_address_pool_association.master_internal.*.id}",
    # "${azurerm_network_interface_backend_address_pool_association.worker.*.id}",
    "${list(azurerm_network_interface_backend_address_pool_association.internal_lb_bootstrap.id)}",
  )}"
}


# locals {
#   controlplane_lb_association_pool_ids = [
#     "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}",
#     "${azurerm_lb_backend_address_pool.external_lb_controlplane_pool.id}"

#   ]
#   controlplane_pools_product = setproduct(range(0, var.master_count), local.controlplane_lb_association_pool_ids)
#   controlplane_pools_map = {
#     for pool in local.controlplane_pools_product :
#     index(local.controlplane_pools_product, pool) => [{ "count" = pool[0], "id" = pool[1] }]
#   }
#   worker_lb_association_pool_ids = [
#     "${azurerm_lb_backend_address_pool.worker_public_lb_pool.id}"
#   ]
#   worker_pools_product = setproduct(range(0, var.master_count), local.worker_lb_association_pool_ids)
#   worker_pools_map = {
#     for pool in local.worker_pools_product :
#     index(local.worker_pools_product, pool) => [{ "count" = pool[0], "id" = pool[1] }]
#   }
# }

# output "controlplane_pools_map" {
#   value = local.controlplane_pools_map
# }

# output "worker_pools_map" {
#   value = local.worker_pools_map
# }
