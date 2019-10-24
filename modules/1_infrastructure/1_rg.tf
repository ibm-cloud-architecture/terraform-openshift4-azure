locals {
  cluster_nr = "${element(split("-", "${var.cluster_id}"), 1)}"
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "write_private_key" {
  content         = "${tls_private_key.installkey.private_key_pem}"
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = "${tls_private_key.installkey.public_key_openssh}"
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa.pub"
  file_permission = 0600
}

# Resource Group to Deploy infrastructure to
resource "azurerm_resource_group" "openshift" {
  name     = "${var.cluster_id}-rg"
  location = "${var.azure_region}"
}
