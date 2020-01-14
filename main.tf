provider "azurerm" {
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  # need version 1.33 until a newer version can handle creating azurerm_images with
  # hyperVGeneration property
  # https://github.com/terraform-providers/terraform-provider-azurerm/issues/4361
  version = "~> 1.40.0"
}

resource "random_string" "cluster_id" {
  length  = 5
  special = false
  upper   = false
}

locals {
  cluster_id = "${var.cluster_name}-${random_string.cluster_id.result}"
  tags = merge(
    {
      "kubernetes.io_cluster.${local.cluster_id}" = "owned"
    },
    var.azure_extra_tags,
  )
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "write_private_key" {
  content         = tls_private_key.installkey.private_key_pem
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = tls_private_key.installkey.public_key_openssh
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa.pub"
  file_permission = 0600
}

module "vnet" {
  source              = "./vnet"
  resource_group_name = azurerm_resource_group.main.name
  vnet_cidr           = var.machine_cidr
  cluster_id          = local.cluster_id
  region              = var.azure_region
  dns_label           = local.cluster_id
  airgapped           = var.airgapped
}

module "ignition" {
  source                        = "./ignition"
  base_domain                   = var.base_domain
  openshift_version             = var.openshift_version
  master_count                  = var.openshift_master_count
  cluster_name                  = var.cluster_name
  cluster_network_cidr          = var.openshift_cluster_network_cidr
  cluster_network_host_prefix   = var.openshift_cluster_network_host_prefix
  machine_cidr                  = var.machine_cidr
  service_network_cidr          = var.openshift_service_network_cidr
  azure_dns_resource_group_name = var.azure_base_domain_resource_group_name
  openshift_pull_secret         = var.openshift_pull_secret
  public_ssh_key                = chomp(tls_private_key.installkey.public_key_openssh)
  cluster_id                    = local.cluster_id
  resource_group_name           = azurerm_resource_group.main.name
  node_count                    = var.openshift_worker_count
  infra_count                   = var.openshift_infra_count
  azure_region                  = var.azure_region
  worker_vm_type                = var.azure_worker_vm_type
  infra_vm_type                 = var.azure_infra_vm_type
  master_vm_type                = var.azure_master_vm_type
  worker_os_disk_size           = var.azure_worker_root_volume_size
  infra_os_disk_size            = var.azure_infra_root_volume_size
  master_os_disk_size           = var.azure_master_root_volume_size
  azure_subscription_id         = var.azure_subscription_id
  azure_client_id               = var.azure_client_id
  azure_client_secret           = var.azure_client_secret
  azure_tenant_id               = var.azure_tenant_id
  azure_rhcos_image_id          = azurerm_image.cluster.id
  virtual_network_name          = module.vnet.virtual_network_name
  private                       = module.vnet.private
  airgapped                     = var.airgapped
}

module "bootstrap" {
  source              = "./bootstrap"
  resource_group_name = azurerm_resource_group.main.name
  region              = var.azure_region
  vm_size             = var.azure_bootstrap_vm_type
  vm_image            = azurerm_image.cluster.id
  identity            = azurerm_user_assigned_identity.main.id
  cluster_id          = local.cluster_id
  ignition            = module.ignition.bootstrap_ignition
  subnet_id           = module.vnet.master_subnet_id
  elb_backend_pool_id = module.vnet.public_lb_backend_pool_id
  ilb_backend_pool_id = module.vnet.internal_lb_backend_pool_id
  tags                = local.tags
  storage_account     = azurerm_storage_account.cluster
  nsg_name            = module.vnet.master_nsg_name
  private             = module.vnet.private
  bootstrap_completed = var.bootstrap_completed
}


module "master" {
  source              = "./master"
  resource_group_name = azurerm_resource_group.main.name
  cluster_id          = local.cluster_id
  region              = var.azure_region
  vm_size             = var.azure_master_vm_type
  vm_image            = azurerm_image.cluster.id
  identity            = azurerm_user_assigned_identity.main.id
  ignition            = module.ignition.master_ignition
  external_lb_id      = module.vnet.public_lb_id
  elb_backend_pool_id = module.vnet.public_lb_backend_pool_id
  ilb_backend_pool_id = module.vnet.internal_lb_backend_pool_id
  subnet_id           = module.vnet.master_subnet_id
  instance_count      = var.openshift_master_count
  storage_account     = azurerm_storage_account.cluster
  os_volume_type      = var.azure_master_root_volume_type
  os_volume_size      = var.azure_master_root_volume_size
  private             = module.vnet.private
}

module "dns" {
  source                          = "./dns"
  cluster_domain                  = "${var.cluster_name}.${var.base_domain}"
  cluster_id                      = local.cluster_id
  base_domain                     = var.base_domain
  virtual_network_id              = module.vnet.virtual_network_id
  external_lb_fqdn                = module.vnet.public_lb_pip_fqdn
  internal_lb_ipaddress           = module.vnet.internal_lb_ip_address
  resource_group_name             = azurerm_resource_group.main.name
  base_domain_resource_group_name = var.azure_base_domain_resource_group_name
  etcd_count                      = var.openshift_master_count
  etcd_ip_addresses               = module.master.ip_addresses
  private                         = module.vnet.private
}


resource "azurerm_resource_group" "main" {
  name     = "${local.cluster_id}-rg"
  location = var.azure_region
  tags     = local.tags
}

resource "azurerm_storage_account" "cluster" {
  name                     = "cluster${random_string.cluster_id.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_user_assigned_identity" "main" {
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  name = "${local.cluster_id}-identity"
}

resource "azurerm_role_assignment" "main" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_storage_container" "vhd" {
  name                 = "vhd"
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_name = azurerm_storage_account.cluster.name
}

resource "azurerm_storage_blob" "rhcos_image" {
  name                   = "rhcos${random_string.cluster_id.result}.vhd"
  resource_group_name    = azurerm_resource_group.main.name
  storage_account_name   = azurerm_storage_account.cluster.name
  storage_container_name = azurerm_storage_container.vhd.name
  type                   = "block"
  source_uri             = var.azure_image_url
  metadata               = map("source_uri", var.azure_image_url)
  attempts               = 2
  lifecycle {
    ignore_changes = [
      type
    ]
  }
}

resource "azurerm_image" "cluster" {
  name                = local.cluster_id
  resource_group_name = azurerm_resource_group.main.name
  location            = var.azure_region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = azurerm_storage_blob.rhcos_image.url
  }
}

