resource "azurerm_storage_account" "ignition" {
  name                     = "ignition${local.cluster_nr}"
  resource_group_name      = var.resource_group_name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account_sas" "ignition" {
  connection_string = azurerm_storage_account.ignition.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start = timestamp()

  expiry = timeadd(timestamp(), "24h")

  permissions {
    read    = true
    list    = true
    create  = false
    add     = false
    delete  = false
    process = false
    write   = false
    update  = false
  }
}

resource "azurerm_storage_container" "ignition" {
  name                  = "ignition"
  storage_account_name  = azurerm_storage_account.ignition.name
  container_access_type = "private"
}

locals {
  installer_workspace     = "${path.root}/installer-files/"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}"
  cluster_nr              = join("", split("-", var.cluster_id))
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when = create
    command = templatefile("${path.module}/scripts/download.sh.tmpl", {
      installer_workspace  = local.installer_workspace
      installer_url        = local.openshift_installer_url
      airgapped_enabled    = var.airgapped["enabled"]
      airgapped_repository = var.airgapped["repository"]
      pull_secret          = var.openshift_pull_secret
      openshift_version    = var.openshift_version
      path_root            = path.root
    })
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ./installer-files"
  }

}


resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/manifests.sh.tmpl", {
      installer_workspace = local.installer_workspace
    })
  }
}

# see templates.tf for generation of yaml config files

resource "null_resource" "generate_ignition" {
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
    null_resource.generate_manifests,
    local_file.cluster-infrastructure-02-config,
    local_file.cluster-dns-02-config,
    local_file.cloud-provider-config,
    local_file.openshift-cluster-api_master-machines,
    local_file.openshift-cluster-api_worker-machineset,
    local_file.openshift-cluster-api_infra-machineset,
    #local_file.ingresscontroller-default,
    local_file.cloud-creds-secret-kube-system,
    #local_file.cluster-scheduler-02-config,
    local_file.cluster-monitoring-configmap,
    #local_file.private-cluster-outbound-service,
  ]

  provisioner "local-exec" {
    command = templatefile("${path.module}/scripts/ignition.sh.tmpl", {
      installer_workspace = local.installer_workspace
      cluster_id          = var.cluster_id
    })
  }
}

resource "azurerm_storage_blob" "ignition-bootstrap" {
  name                   = "bootstrap.ign"
  source                 = "${local.installer_workspace}/bootstrap.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-master" {
  name                   = "master.ign"
  source                 = "${local.installer_workspace}/master.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-worker" {
  name                   = "worker.ign"
  source                 = "${local.installer_workspace}/worker.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

data "ignition_config" "master_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-master.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-bootstrap.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-worker.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}
