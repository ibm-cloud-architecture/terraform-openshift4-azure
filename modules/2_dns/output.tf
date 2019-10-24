output "module_completed" {
  value = "${join(",",
    list(azurerm_dns_zone.private.id),
    list(azurerm_dns_cname_record.apiint_internal.id),
    list(azurerm_dns_cname_record.api_internal.id),
    list(azurerm_dns_cname_record.router_internal.id),
    list(azurerm_dns_cname_record.api_external.id),
    list(azurerm_dns_cname_record.router_external.id),
    azurerm_dns_a_record.etcd_a_nodes.*.id,
    list(azurerm_dns_srv_record.etcd_cluster.id),
  )}"
}
