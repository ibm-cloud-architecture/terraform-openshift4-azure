provider "azurerm" {
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  # need version 1.33 until a newer version can handle creating azurerm_images with
  # hyperVGeneration property
  # https://github.com/terraform-providers/terraform-provider-azurerm/issues/4361
  version = "<= 1.33"
}

resource "random_string" "tag" {
  length  = 5
  special = false
  upper   = false
}

locals {
  cluster_id = "${var.openshift_cluster_name}-${random_string.tag.result}"
}

module "infrastructure" {
  source          = "./modules/1_infrastructure"
  cluster_id      = local.cluster_id
  azure_region    = var.azure_region
  machine_cidr    = var.machine_cidr
  master_count    = var.openshift_master_count
  worker_count    = var.openshift_worker_count
  azure_image_url = var.azure_rhcos_image_url
}

module "dns" {
  source = "./modules/2_dns"
  dependson = [
    "${module.infrastructure.module_completed}",
  ]
  cluster_domain                = "${var.openshift_cluster_name}.${var.base_domain}"
  base_domain                   = var.base_domain
  apps_external_lb_fqdn         = module.infrastructure.apps_lb_pip_fqdn
  cluster_external_lb_fqdn      = module.infrastructure.cluster_lb_pip_fqdn
  internal_lb_ipaddress         = module.infrastructure.internal_lb_ip_address
  resource_group_name           = module.infrastructure.resource_group_name
  azure_dns_resource_group_name = var.azure_dns_resource_group_name
  etcd_count                    = var.openshift_master_count
  etcd_ip_addresses             = module.infrastructure.master_ip_addresses
  vnet_ids = [
    module.infrastructure.controlplane_vnet_id,
    module.infrastructure.worker_vnet_id
  ]
}

module "ignition" {
  source = "./modules/3_ignition"

  dependson = [
    "${module.infrastructure.module_completed}",
    "${module.dns.module_completed}",
  ]

  base_domain                   = var.base_domain
  openshift_version             = var.openshift_version
  master_count                  = var.openshift_master_count
  cluster_name                  = var.openshift_cluster_name
  cluster_network_cidr          = var.openshift_cluster_network_cidr
  cluster_network_host_prefix   = var.openshift_cluster_network_host_prefix
  machine_cidr                  = var.machine_cidr
  service_network_cidr          = var.openshift_service_network_cidr
  azure_dns_resource_group_name = var.azure_dns_resource_group_name
  openshift_pull_secret         = chomp(file(var.openshift_pull_secret))
  public_ssh_key                = module.infrastructure.public_ssh_key
  cluster_id                    = local.cluster_id
  resource_group_name           = module.infrastructure.resource_group_name
  storage_account_name          = module.infrastructure.storage_account_name
  storage_container_name        = module.infrastructure.storage_container_name
  storage_account_sas           = module.infrastructure.storage_account_sas
  node_count                    = var.openshift_worker_count
  etcd_ip_addresses             = module.infrastructure.master_ip_addresses
  azure_region                  = var.azure_region
  worker_vm_type                = var.azure_worker_vm_type
  master_vm_type                = var.azure_master_vm_type
  worker_os_disk_size           = var.azure_worker_root_volume_size
  master_os_disk_size           = var.azure_master_root_volume_size
  azure_subscription_id         = var.azure_subscription_id
  azure_client_id               = var.azure_client_id
  azure_client_secret           = var.azure_client_secret
  azure_tenant_id               = var.azure_tenant_id
  azure_storage_azurefile_name  = module.infrastructure.azure_storage_azurefile_name
  azure_rhcos_image_id          = module.infrastructure.cluster_image_id
  controlplane_vnet_name        = module.infrastructure.controlplane_vnet_name
  worker_vnet_name              = module.infrastructure.worker_vnet_name
  apps_lb_pip_ip                = module.infrastructure.apps_lb_pip_ip
}

module "bootstrap" {
  source = "./modules/4_bootstrap"
  dependson = [
    "${module.infrastructure.module_completed}",
    "${module.dns.module_completed}",
    "${module.ignition.module_completed}",
  ]
  resource_group_name     = module.infrastructure.resource_group_name
  cluster_id              = local.cluster_id
  azure_region            = var.azure_region
  vm_size                 = var.azure_bootstrap_vm_type
  vm_image                = module.infrastructure.cluster_image_id
  identity                = module.infrastructure.user_assigned_identity_id
  ignition                = module.ignition.bootstrap_ignition
  boot_diag_blob_endpoint = module.infrastructure.boot_diag_blob_endpoint
  nsg_name                = module.infrastructure.master_nsg_name
  network_interface_id    = module.infrastructure.bootstrap_network_interface_id
  bootstrap_complete      = var.bootstrap_complete
}

module "controlplane" {
  source = "./modules/5_nodes"
  dependson = [
    "${module.infrastructure.module_completed}",
    "${module.dns.module_completed}",
    "${module.ignition.module_completed}",
    "${module.bootstrap.module_completed}"
  ]
  instance_count          = var.openshift_master_count
  resource_group_name     = module.infrastructure.resource_group_name
  cluster_id              = local.cluster_id
  azure_region            = var.azure_region
  vm_size                 = var.azure_master_vm_type
  vm_image                = module.infrastructure.cluster_image_id
  identity                = module.infrastructure.user_assigned_identity_id
  ignition                = module.ignition.master_ignition
  boot_diag_blob_endpoint = module.infrastructure.boot_diag_blob_endpoint
  network_intreface_id    = module.infrastructure.master_network_interface_id
  os_volume_size          = var.azure_master_root_volume_size
  node_type               = "master"
  network_interface_ids   = module.infrastructure.master_network_interface_id
  backend_address_pool_id = module.infrastructure.internal_lb_controlplane_pool_id
}

# module "worker" {
#   source = "./modules/5_nodes"
#   dependson = [
#     "${module.infrastructure.module_completed}",
#     "${module.dns.module_completed}",
#     "${module.ignition.module_completed}",
#     "${module.bootstrap.module_completed}"
#   ]
#   instance_count          = var.openshift_worker_count
#   resource_group_name     = module.infrastructure.resource_group_name
#   cluster_id              = local.cluster_id
#   azure_region            = var.azure_region
#   vm_size                 = var.azure_worker_vm_type
#   vm_image                = module.infrastructure.cluster_image_id
#   identity                = module.infrastructure.user_assigned_identity_id
#   ignition                = module.ignition.worker_ignition
#   boot_diag_blob_endpoint = module.infrastructure.boot_diag_blob_endpoint
#   network_intreface_id    = module.infrastructure.worker_network_interface_id
#   os_volume_size          = var.azure_worker_root_volume_size
#   node_type               = "worker"
#   network_interface_ids   = module.infrastructure.worker_network_interface_id
#   backend_address_pool_id = module.infrastructure.worker_lb_backend_pool_id
# }


module "deploy" {
  source = "./modules/6_deploy"
  dependson = [
    "${module.infrastructure.module_completed}",
    "${module.dns.module_completed}",
    "${module.ignition.module_completed}",
    "${module.bootstrap.module_completed}",
    "${module.controlplane.module_completed}",
    # "${module.worker.module_completed}",
  ]
  azure_region        = var.azure_region
  resource_group_name = module.infrastructure.resource_group_name
  cluster_id          = local.cluster_id
}
