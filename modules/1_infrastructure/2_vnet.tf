
locals {
  master_subnet_cidr = "${cidrsubnet(var.machine_cidr, 3, 0)}"
  node_subnet_cidr   = "${cidrsubnet(var.machine_cidr, 3, 1)}"
}


resource "azurerm_virtual_network" "openshift" {
  name                = "${var.cluster_id}-vnet"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"
  address_space       = ["${var.machine_cidr}"]
}

resource "azurerm_subnet" "master_subnet" {
  resource_group_name  = "${azurerm_resource_group.openshift.name}"
  virtual_network_name = "${azurerm_virtual_network.openshift.name}"
  address_prefix       = "${local.master_subnet_cidr}"
  name                 = "${var.cluster_id}-master-subnet"
}

resource "azurerm_subnet" "node_subnet" {
  resource_group_name  = "${azurerm_resource_group.openshift.name}"
  virtual_network_name = "${azurerm_virtual_network.openshift.name}"
  address_prefix       = "${local.node_subnet_cidr}"
  name                 = "${var.cluster_id}-worker-subnet"
}

