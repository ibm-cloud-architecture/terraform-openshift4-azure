locals {
  bootstrap_nic_ip_configuration_name = "bootstrap-nic-ip"
}

resource "azurerm_public_ip" "bootstrap_public_ip" {
  count = var.bootstrap_completed ? 0 : var.private ? 0 : 1

  sku                 = "Standard"
  location            = var.region
  name                = "${var.cluster_id}-bootstrap-pip"
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

data "azurerm_public_ip" "bootstrap_public_ip" {
  count = var.bootstrap_completed ? 0 : var.private ? 0 : 1

  name                = azurerm_public_ip.bootstrap_public_ip[0].name
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_interface" "bootstrap" {
  count = var.bootstrap_completed ? 0 : 1

  name                = "${var.cluster_id}-bootstrap-nic"
  location            = var.region
  resource_group_name = var.resource_group_name

  ip_configuration {
    subnet_id                     = var.subnet_id
    name                          = local.bootstrap_nic_ip_configuration_name
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.private ? null : azurerm_public_ip.bootstrap_public_ip[0].id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "public_lb_bootstrap" {
  count = var.bootstrap_completed ? 0 : 1

  network_interface_id    = element(azurerm_network_interface.bootstrap.*.id, count.index)
  backend_address_pool_id = var.elb_backend_pool_id
  ip_configuration_name   = local.bootstrap_nic_ip_configuration_name
}

resource "azurerm_network_interface_backend_address_pool_association" "internal_lb_bootstrap" {
  count = var.bootstrap_completed ? 0 : 1

  network_interface_id    = element(azurerm_network_interface.bootstrap.*.id, count.index)
  backend_address_pool_id = var.ilb_backend_pool_id
  ip_configuration_name   = local.bootstrap_nic_ip_configuration_name
}

resource "azurerm_virtual_machine" "bootstrap" {
  count = var.bootstrap_completed ? 0 : 1

  name                  = "${var.cluster_id}-bootstrap"
  location              = var.region
  resource_group_name   = var.resource_group_name
  network_interface_ids = [element(azurerm_network_interface.bootstrap.*.id, count.index)]
  vm_size               = var.vm_size

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity]
  }

  storage_os_disk {
    name              = "${var.cluster_id}-bootstrap_OSDisk" # os disk name needs to match cluster-api convention
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 100
  }

  storage_image_reference {
    id = var.vm_image
  }

  os_profile {
    computer_name  = "${var.cluster_id}-bootstrap-vm"
    admin_username = "core"
    # The password is normally applied by WALA (the Azure agent), but this
    # isn't installed in RHCOS. As a result, this password is never set. It is
    # included here because it is required by the Azure ARM API.
    admin_password = "NotActuallyApplied!"
    custom_data    = var.ignition
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = var.storage_account.primary_blob_endpoint
  }

  depends_on = [
    azurerm_network_interface_backend_address_pool_association.public_lb_bootstrap,
    azurerm_network_interface_backend_address_pool_association.internal_lb_bootstrap
  ]
}

resource "azurerm_network_security_rule" "bootstrap_ssh_in" {
  count = var.bootstrap_completed ? 0 : 1

  name                        = "bootstrap_ssh_in"
  priority                    = 103
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = var.nsg_name
}
