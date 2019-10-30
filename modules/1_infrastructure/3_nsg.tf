resource "azurerm_network_security_group" "worker" {
  name                = "${var.cluster_id}-node-nsg"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
}


resource "azurerm_network_security_group" "master" {
  name                = "${var.cluster_id}-controlplane-nsg"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
}


locals {
  common_nsg_rules = {
    101 = { "name" : "etcd_in", "range" : "2378-2380", "proto" : "Tcp" }
    102 = { "name" : "kubeadmin_in", "range" : "6443", "proto" : "Tcp" }
    103 = { "name" : "hostsercices_in_tcp", "range" : "9000-9999", "proto" : "Tcp" }
    104 = { "name" : "kubereserves_in", "range" : "10249-10259", "proto" : "Tcp" }
    105 = { "name" : "openshiftsdn_in", "range" : "10256", "proto" : "Tcp" }
    106 = { "name" : "vxlan_in", "range" : "4789", "proto" : "Udp" }
    107 = { "name" : "geneve_in", "range" : "6081", "proto" : "Udp" }
    108 = { "name" : "hostsercices_in_udp", "range" : "10249-10259", "proto" : "Udp" }
    109 = { "name" : "kubenodeport_in", "range" : "30000-32767", "proto" : "Udp" }
  }
}

resource "azurerm_network_security_rule" "master_rule" {
  for_each                    = local.common_nsg_rules
  priority                    = each.key
  name                        = each.value.name
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = each.value.proto
  source_port_range           = "*"
  destination_port_range      = each.value.range
  source_address_prefix       = var.machine_cidr
  destination_address_prefix  = local.controlplane_subnet_cidr
  resource_group_name         = azurerm_resource_group.openshift.name
  network_security_group_name = azurerm_network_security_group.master.name
}

resource "azurerm_network_security_rule" "worker_rule" {
  for_each                    = local.common_nsg_rules
  priority                    = each.key
  name                        = each.value.name
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = each.value.proto
  source_port_range           = "*"
  destination_port_range      = each.value.range
  source_address_prefix       = var.machine_cidr
  destination_address_prefix  = local.worker_subnet_cidr
  resource_group_name         = azurerm_resource_group.openshift.name
  network_security_group_name = azurerm_network_security_group.worker.name
}

resource "azurerm_network_security_rule" "apiserver_in" {
  name                        = "apiserver_in_world"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.openshift.name}"
  network_security_group_name = "${azurerm_network_security_group.master.name}"
}

resource "azurerm_network_security_rule" "bootstrap_in" {
  name                        = "bootstrap_in"
  priority                    = 111
  access                      = "Allow"
  direction                   = "Inbound"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22623"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.openshift.name}"
  network_security_group_name = "${azurerm_network_security_group.master.name}"
}

# resource "azurerm_network_security_rule" "tcp-http" {
#   name                        = "tcp-80"
#   priority                    = 109
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "80"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "VirtualNetwork"
#   resource_group_name         = "${azurerm_resource_group.openshift.name}"
#   network_security_group_name = "${azurerm_network_security_group.worker.name}"
# }

# resource "azurerm_network_security_rule" "tcp-https" {
#   name                        = "tcp-443"
#   priority                    = 110
#   access                      = "Allow"
#   direction                   = "Inbound"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "443"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "VirtualNetwork"
#   resource_group_name         = "${azurerm_resource_group.openshift.name}"
#   network_security_group_name = "${azurerm_network_security_group.worker.name}"
# }

# NOTE: At this time Subnet <-> Network Security Group associations need to be configured both using
# this field (which is now Deprecated) and/or using the azurerm_subnet_network_security_group_association
# resource. This field is deprecated and will be removed in favour of that resource in the next
# major version (2.0) of the AzureRM Provider.
# 10/24/19
# https://www.terraform.io/docs/providers/azurerm/r/subnet.html
# resource "azurerm_subnet_network_security_group_association" "worker" {
#   subnet_id                 = "${azurerm_subnet.node_subnet.id}"
#   network_security_group_id = "${azurerm_network_security_group.worker.id}"
# }

# resource "azurerm_subnet_network_security_group_association" "master" {
#   subnet_id                 = "${azurerm_subnet.master_subnet.id}"
#   network_security_group_id = "${azurerm_network_security_group.master.id}"
# }

resource "azurerm_subnet" "master_subnet" {
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.controlplane.name}"
  address_prefix            = "${local.controlplane_subnet_cidr}"
  name                      = "${var.cluster_id}-master-subnet"
  network_security_group_id = azurerm_network_security_group.master.id
}

resource "azurerm_subnet" "node_subnet" {
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.worker.name}"
  address_prefix            = "${local.worker_subnet_cidr}"
  name                      = "${var.cluster_id}-worker-subnet"
  network_security_group_id = azurerm_network_security_group.worker.id
}
