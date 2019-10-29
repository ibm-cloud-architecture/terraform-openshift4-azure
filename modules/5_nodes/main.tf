resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  // The name of the masters' ipconfiguration is hardcoded to "pipconfig". It needs to match cluster-api
  // https://github.com/openshift/cluster-api-provider-azure/blob/master/pkg/cloud/azure/services/networkinterfaces/networkinterfaces.go#L131
  ip_configuration_name = "pipConfig"
}

data "azurerm_subscription" "current" {}

resource "azurerm_virtual_machine" "node" {
  count = "${var.instance_count}"

  lifecycle {
    ignore_changes = [
      "os_profile"
    ]
  }

  name                  = "${var.cluster_id}-${var.node_type}-${count.index}"
  location              = "${var.azure_region}"
  resource_group_name   = "${var.resource_group_name}"
  network_interface_ids = ["${element(var.network_intreface_id, count.index)}"]
  vm_size               = "${var.vm_size}"
  zones                 = ["${count.index % 3 + 1}"]
  tags                  = { "openshift" : "${var.node_type}" }

  delete_os_disk_on_termination = true

  identity {
    type         = "UserAssigned"
    identity_ids = ["${var.identity}"]
  }

  storage_os_disk {
    name              = "${var.cluster_id}-${var.node_type}-${count.index}_OSDisk" # os disk name needs to match cluster-api convention
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    disk_size_gb      = "${var.os_volume_size}"
  }

  storage_image_reference {
    id = "${data.azurerm_subscription.current.id}${var.vm_image}"
  }

  //we don't provide a ssh key, because it is set with ignition. 
  //it is required to provide at least 1 auth method to deploy a linux vm
  os_profile {
    computer_name  = "${var.cluster_id}-${var.node_type}-${count.index}"
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

# hack - internal loadbalancers can't handle hairpin NAT
# https://docs.microsoft.com/en-us/azure/load-balancer/load-balancer-overview#limitations
# we add the servers to the backend server pool after bootstrap is complete otherwise
# it could ask for bootstrap information from itself and fail.
resource "azurerm_network_interface_backend_address_pool_association" "node_association" {
  count                   = var.node_type == "master" ? var.instance_count : 0
  network_interface_id    = element(var.network_interface_ids, count.index)
  backend_address_pool_id = var.backend_address_pool_id
  ip_configuration_name   = local.ip_configuration_name
  depends_on = [
    "azurerm_virtual_machine.node"
  ]
}
