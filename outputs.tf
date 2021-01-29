output "cluster_id" {
  value = local.cluster_id
}

output "resource_group" {
  value = data.azurerm_resource_group.main.name
}

output "bootstrap_public_ip" {
  value = module.bootstrap.bootstrap_public_ip
}
