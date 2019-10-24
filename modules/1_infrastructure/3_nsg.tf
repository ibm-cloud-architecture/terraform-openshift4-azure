resource "azurerm_network_security_group" "worker" {
  name                = "${var.cluster_id}-node-nsg"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  depends_on = [
    "azurerm_network_interface.worker"
  ]
}

resource "azurerm_subnet_network_security_group_association" "worker" {
  subnet_id                 = "${azurerm_subnet.node_subnet.id}"
  network_security_group_id = "${azurerm_network_security_group.worker.id}"
}

resource "azurerm_network_security_group" "master" {
  name                = "${var.cluster_id}-controlplane-nsg"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  depends_on = [
    "azurerm_network_interface.master",
    "azurerm_network_interface.bootstrap"
  ]
}

resource "azurerm_subnet_network_security_group_association" "master" {
  subnet_id                 = "${azurerm_subnet.master_subnet.id}"
  network_security_group_id = "${azurerm_network_security_group.master.id}"
}

resource "azurerm_network_security_rule" "apiserver_in" {
  name                        = "apiserver_in"
  priority                    = 101
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
  priority                    = 102
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

resource "azurerm_network_security_rule" "tcp-http" {
  name                        = "tcp-80"
  priority                    = 500
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = "${azurerm_resource_group.openshift.name}"
  network_security_group_name = "${azurerm_network_security_group.worker.name}"
}

resource "azurerm_network_security_rule" "tcp-https" {
  name                        = "tcp-443"
  priority                    = 501
  access                      = "Allow"
  direction                   = "Inbound"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = "${azurerm_resource_group.openshift.name}"
  network_security_group_name = "${azurerm_network_security_group.worker.name}"
}
