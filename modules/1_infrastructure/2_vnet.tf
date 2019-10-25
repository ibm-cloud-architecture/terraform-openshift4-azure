
locals {
  controlplane_subnet_cidr = "${cidrsubnet(var.machine_cidr, 3, 0)}"
  worker_subnet_cidr       = "${cidrsubnet(var.machine_cidr, 3, 1)}"
}


resource "azurerm_virtual_network" "controlplane" {
  name                = "${var.cluster_id}-controlplane-vnet"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"
  address_space       = ["${local.controlplane_subnet_cidr}"]
}

# NOTE: At this time Subnet <-> Network Security Group associations need to be configured both using
# this field (which is now Deprecated) and/or using the azurerm_subnet_network_security_group_association
# resource. This field is deprecated and will be removed in favour of that resource in the next
# major version (2.0) of the AzureRM Provider.
# 10/24/19
# https://www.terraform.io/docs/providers/azurerm/r/subnet.html

resource "azurerm_subnet" "master_subnet" {
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.controlplane.name}"
  address_prefix            = "${local.controlplane_subnet_cidr}"
  name                      = "${var.cluster_id}-master-subnet"
  network_security_group_id = azurerm_network_security_group.master.id
}

resource "azurerm_virtual_network" "worker" {
  name                = "${var.cluster_id}-worker-vnet"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"
  address_space       = ["${local.worker_subnet_cidr}"]
}

resource "azurerm_subnet" "node_subnet" {
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.worker.name}"
  address_prefix            = "${local.worker_subnet_cidr}"
  name                      = "${var.cluster_id}-worker-subnet"
  network_security_group_id = azurerm_network_security_group.worker.id
}

resource "azurerm_virtual_network_peering" "controlplane2worker" {
  name                      = "controlplane2worker"
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.controlplane.name}"
  remote_virtual_network_id = "${azurerm_virtual_network.worker.id}"
}

resource "azurerm_virtual_network_peering" "worker2controlplane" {
  name                      = "worker2controlplane"
  resource_group_name       = "${azurerm_resource_group.openshift.name}"
  virtual_network_name      = "${azurerm_virtual_network.worker.name}"
  remote_virtual_network_id = "${azurerm_virtual_network.controlplane.id}"
}
