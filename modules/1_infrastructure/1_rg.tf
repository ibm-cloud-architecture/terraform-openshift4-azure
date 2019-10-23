locals {
  cluster_nr = "${element(split("-", "${var.cluster_id}"), 1)}"
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Resource Group to Deploy infrastructure to
resource "azurerm_resource_group" "openshift" {
  name     = "${var.cluster_id}-rg"
  location = "${var.azure_region}"
}
