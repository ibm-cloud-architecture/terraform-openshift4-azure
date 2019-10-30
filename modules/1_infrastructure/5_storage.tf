# Storage Account to host ignition blobs
resource "azurerm_storage_account" "ignition" {
  name                     = "ignition${local.cluster_nr}"
  resource_group_name      = "${azurerm_resource_group.openshift.name}"
  location                 = "${var.azure_region}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account_sas" "ignition" {
  connection_string = "${azurerm_storage_account.ignition.primary_connection_string}"
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

  start = "${timestamp()}"

  expiry = "${timeadd(timestamp(), "24h")}"

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
  # resource_group_name   = "${azurerm_resource_group.openshift.name}"
  name                  = "ignition"
  storage_account_name  = azurerm_storage_account.ignition.name
  container_access_type = "private"
}

resource "azurerm_storage_account" "bootdiag" {
  name                     = "bootdiag${local.cluster_nr}"
  resource_group_name      = azurerm_resource_group.openshift.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_account" "azurefile" {
  name                     = "azurefile${local.cluster_nr}"
  resource_group_name      = azurerm_resource_group.openshift.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "azurefile" {
  name                 = "azurefile${local.cluster_nr}"
  storage_account_name = azurerm_storage_account.azurefile.name
  quota                = 100
}


# RHCOS image
resource "azurerm_storage_account" "rhcos" {
  name                     = "rhcosimage${local.cluster_nr}"
  resource_group_name      = azurerm_resource_group.openshift.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "vhd" {
  name                 = "vhd"
  resource_group_name  = azurerm_resource_group.openshift.name
  storage_account_name = azurerm_storage_account.rhcos.name
}

resource "azurerm_storage_blob" "rhcos_image" {
  name                   = "rhcos.vhd"
  resource_group_name    = azurerm_resource_group.openshift.name
  storage_account_name   = azurerm_storage_account.rhcos.name
  storage_container_name = azurerm_storage_container.vhd.name
  type                   = "block"
  source_uri             = var.azure_image_url
  metadata               = map("source_uri", var.azure_image_url)
  attempts               = 2
}

resource "azurerm_image" "cluster" {
  name                = var.cluster_id
  resource_group_name = azurerm_resource_group.openshift.name
  location            = var.azure_region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = azurerm_storage_blob.rhcos_image.url
  }

  lifecycle {
    ignore_changes = [
      "os_disk"
    ]
  }
}
