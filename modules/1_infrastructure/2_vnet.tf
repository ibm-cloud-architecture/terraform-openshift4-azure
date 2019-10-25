
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

resource "azurerm_virtual_network" "worker" {
  name                = "${var.cluster_id}-worker-vnet"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"
  address_space       = ["${local.worker_subnet_cidr}"]
}


resource "azurerm_virtual_network_peering" "controlplane2worker" {
  name                         = "controlplane2worker"
  resource_group_name          = "${azurerm_resource_group.openshift.name}"
  virtual_network_name         = "${azurerm_virtual_network.controlplane.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.worker.id}"
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "worker2controlplane" {
  name                         = "worker2controlplane"
  resource_group_name          = "${azurerm_resource_group.openshift.name}"
  virtual_network_name         = "${azurerm_virtual_network.worker.name}"
  remote_virtual_network_id    = "${azurerm_virtual_network.controlplane.id}"
  allow_virtual_network_access = true
}
