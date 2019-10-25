resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  bootstrap_nic_ip_configuration_name = "bootstrap-nic-ip"
}

data "azurerm_subscription" "current" {}

resource "azurerm_virtual_machine" "bootstrap" {
  count = "${var.bootstrap_complete ? 0 : 1}"
  lifecycle {
    ignore_changes = [
      "os_profile"
    ]
  }

  name                  = "${var.cluster_id}-bootstrap"
  location              = "${var.azure_region}"
  resource_group_name   = "${var.resource_group_name}"
  network_interface_ids = ["${var.network_interface_id}"]
  vm_size               = "${var.vm_size}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  identity {
    type         = "UserAssigned"
    identity_ids = ["${var.identity}"]
  }

  storage_os_disk {
    name              = "${var.cluster_id}-bootstrap_OSDisk" # os disk name needs to match cluster-api convention
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = 100
  }

  storage_image_reference {
    id = "${data.azurerm_subscription.current.id}${var.vm_image}"
  }

  os_profile {
    computer_name  = "${var.cluster_id}-bootstrap-vm"
    admin_username = "core"
    # The password is normally applied by WALA (the Azure agent), but this
    # isn't installed in RHCOS. As a result, this password is never set. It is
    # included here because it is required by the Azure ARM API.
    admin_password = "NotActuallyApplied!"
    custom_data    = "${var.ignition}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "${var.boot_diag_blob_endpoint}"
  }
  depends_on = [
    "null_resource.dependency"
  ]
}

resource "azurerm_network_security_rule" "bootstrap_ssh_in" {
  name                        = "bootstrap_ssh_in"
  priority                    = 112
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${var.resource_group_name}"
  network_security_group_name = "${var.nsg_name}"
}
