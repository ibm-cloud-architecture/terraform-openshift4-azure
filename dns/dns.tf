locals {
  // extracting "api.<clustername>" from <clusterdomain>
  api_external_name = "api.${replace(var.cluster_domain, ".${var.base_domain}", "")}"
}

resource "azurerm_private_dns_zone" "private" {
  name                = var.cluster_domain
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_dns_cname_record.api_external_v4, azurerm_dns_cname_record.api_external_v6]
}

resource "azurerm_private_dns_zone_virtual_network_link" "network" {
  name                  = "${var.cluster_id}-network-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.private.name
  virtual_network_id    = var.virtual_network_id
}

resource "azurerm_private_dns_a_record" "apiint_internal" {
  // TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  //   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  count = var.use_ipv4 ? 1 : 0

  name                = "api-int"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v4]
}

resource "azurerm_private_dns_aaaa_record" "apiint_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  name                = "api-int"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v6]
}

resource "azurerm_private_dns_a_record" "api_internal" {
  // TODO: internal LB should block v4 for better single stack emulation (&& ! var.emulate_single_stack_ipv6)
  //   but RHCoS initramfs can't do v6 and so fails to ignite. https://issues.redhat.com/browse/GRPA-1343 
  count = var.use_ipv4 ? 1 : 0

  name                = "api"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v4]
}

resource "azurerm_private_dns_aaaa_record" "api_internal_v6" {
  count = var.use_ipv6 ? 1 : 0

  name                = "api"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [var.internal_lb_ipaddress_v6]
}

resource "azurerm_dns_cname_record" "api_external_v4" {
  count = var.private || ! var.use_ipv4 ? 0 : 1

  name                = local.api_external_name
  zone_name           = var.base_domain
  resource_group_name = var.base_domain_resource_group_name
  ttl                 = 300
  record              = var.external_lb_fqdn_v4
}

resource "azurerm_dns_cname_record" "api_external_v6" {
  count = var.private || ! var.use_ipv6 ? 0 : 1

  name                = "v6-${local.api_external_name}"
  zone_name           = var.base_domain
  resource_group_name = var.base_domain_resource_group_name
  ttl                 = 300
  record              = var.external_lb_fqdn_v6
}

resource "azurerm_private_dns_a_record" "etcd_a_nodes" {
  count               = var.etcd_count
  name                = "etcd-${count.index}"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 60
  records             = [var.etcd_ip_addresses[count.index]]
}

resource "azurerm_private_dns_srv_record" "etcd_cluster" {
  name                = "_etcd-server-ssl._tcp"
  zone_name           = azurerm_private_dns_zone.private.name
  resource_group_name = var.resource_group_name
  ttl                 = 60

  dynamic "record" {
    for_each = azurerm_private_dns_a_record.etcd_a_nodes.*.name
    iterator = name
    content {
      target   = "${name.value}.${azurerm_private_dns_zone.private.name}"
      priority = 10
      weight   = 10
      port     = 2380
    }
  }
}
