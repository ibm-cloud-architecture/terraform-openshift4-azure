provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  tenant_id       = var.azure_tenant_id
  environment     = var.azure_environment
}

resource "random_string" "cluster_id" {
  length  = 5
  special = false
  upper   = false
}

# SSH Key for VMs
resource "tls_private_key" "installkey" {
  count     = var.openshift_ssh_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "write_private_key" {
  count           = var.openshift_ssh_key == "" ? 1 : 0
  content         = tls_private_key.installkey[0].private_key_pem
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa"
  file_permission = 0600
}

resource "local_file" "write_public_key" {
  content         = local.public_ssh_key
  filename        = "${path.root}/installer-files/artifacts/openshift_rsa.pub"
  file_permission = 0600
}


data "template_file" "azure_sp_json" {
  template = <<EOF
{
  "subscriptionId":"${var.azure_subscription_id}",
  "clientId":"${var.azure_client_id}",
  "clientSecret":"${var.azure_client_secret}",
  "tenantId":"${var.azure_tenant_id}"
}
EOF
}

resource "local_file" "azure_sp_json" {
  content  = data.template_file.azure_sp_json.rendered
  filename = pathexpand("~/.azure/osServicePrincipal.json")
}

data "http" "images" {
  url = "https://raw.githubusercontent.com/openshift/installer/release-${local.major_version}/data/data/rhcos.json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  cluster_id = "${var.cluster_name}-${random_string.cluster_id.result}"
  tags = merge(
    {
      "kubernetes.io_cluster.${local.cluster_id}" = "owned"
    },
    var.azure_extra_tags,
  )
  azure_network_resource_group_name = (var.azure_preexisting_network && var.azure_network_resource_group_name != null) ? var.azure_network_resource_group_name : data.azurerm_resource_group.main.name
  azure_virtual_network             = (var.azure_preexisting_network && var.azure_virtual_network != null) ? var.azure_virtual_network : "${local.cluster_id}-vnet"
  azure_control_plane_subnet        = (var.azure_preexisting_network && var.azure_control_plane_subnet != null) ? var.azure_control_plane_subnet : "${local.cluster_id}-master-subnet"
  azure_compute_subnet              = (var.azure_preexisting_network && var.azure_compute_subnet != null) ? var.azure_compute_subnet : "${local.cluster_id}-worker-subnet"
  public_ssh_key                    = var.openshift_ssh_key == "" ? tls_private_key.installkey[0].public_key_openssh : file(var.openshift_ssh_key)
  major_version                     = join(".", slice(split(".", var.openshift_version), 0, 2))
  rhcos_image                       = lookup(lookup(jsondecode(data.http.images.body), "azure"), "url")
}

module "vnet" {
  source              = "./vnet"
  resource_group_name = data.azurerm_resource_group.main.name
  vnet_v4_cidrs       = var.machine_v4_cidrs
  vnet_v6_cidrs       = var.machine_v6_cidrs
  cluster_id          = local.cluster_id
  region              = var.azure_region
  dns_label           = local.cluster_id

  preexisting_network         = var.azure_preexisting_network
  network_resource_group_name = local.azure_network_resource_group_name
  virtual_network_name        = local.azure_virtual_network
  master_subnet               = local.azure_control_plane_subnet
  worker_subnet               = local.azure_compute_subnet
  private                     = var.azure_private
  outbound_udr                = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6
}

module "ignition" {
  source                        = "./ignition"
  depends_on                    = [local_file.azure_sp_json]
  base_domain                   = var.base_domain
  openshift_version             = var.openshift_version
  master_count                  = var.master_count
  cluster_name                  = var.cluster_name
  cluster_network_cidr          = var.openshift_cluster_network_cidr
  cluster_network_host_prefix   = var.openshift_cluster_network_host_prefix
  machine_cidr                  = var.machine_v4_cidrs[0]
  service_network_cidr          = var.openshift_service_network_cidr
  azure_dns_resource_group_name = var.azure_base_domain_resource_group_name
  openshift_pull_secret         = var.openshift_pull_secret
  public_ssh_key                = chomp(local.public_ssh_key)
  cluster_id                    = local.cluster_id
  resource_group_name           = data.azurerm_resource_group.main.name
  availability_zones            = var.azure_master_availability_zones
  node_count                    = var.worker_count
  infra_count                   = var.infra_count
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
  virtual_network_name          = local.azure_virtual_network
  network_resource_group_name   = local.azure_network_resource_group_name
  control_plane_subnet          = local.azure_control_plane_subnet
  compute_subnet                = local.azure_compute_subnet
  private                       = module.vnet.private
  outbound_udr                  = var.azure_outbound_user_defined_routing
  airgapped                     = var.airgapped
  proxy_config                  = var.proxy_config
  trust_bundle                  = var.openshift_additional_trust_bundle
  byo_dns                       = var.openshift_byo_dns
}

module "bootstrap" {
  source                 = "./bootstrap"
  resource_group_name    = data.azurerm_resource_group.main.name
  region                 = var.azure_region
  vm_size                = var.azure_bootstrap_vm_type
  vm_image               = azurerm_image.cluster.id
  identity               = azurerm_user_assigned_identity.main.id
  cluster_id             = local.cluster_id
  ignition               = module.ignition.bootstrap_ignition
  subnet_id              = module.vnet.master_subnet_id
  elb_backend_pool_v4_id = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id = module.vnet.internal_lb_backend_pool_v4_id
  ilb_backend_pool_v6_id = module.vnet.internal_lb_backend_pool_v6_id
  tags                   = local.tags
  storage_account        = azurerm_storage_account.cluster
  nsg_name               = module.vnet.cluster_nsg_name
  private                = module.vnet.private
  outbound_udr           = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6
}

module "master" {
  source                 = "./master"
  resource_group_name    = data.azurerm_resource_group.main.name
  cluster_id             = local.cluster_id
  region                 = var.azure_region
  availability_zones     = var.azure_master_availability_zones
  vm_size                = var.azure_master_vm_type
  vm_image               = azurerm_image.cluster.id
  identity               = azurerm_user_assigned_identity.main.id
  ignition               = module.ignition.master_ignition
  elb_backend_pool_v4_id = module.vnet.public_lb_backend_pool_v4_id
  elb_backend_pool_v6_id = module.vnet.public_lb_backend_pool_v6_id
  ilb_backend_pool_v4_id = module.vnet.internal_lb_backend_pool_v4_id
  ilb_backend_pool_v6_id = module.vnet.internal_lb_backend_pool_v6_id
  subnet_id              = module.vnet.master_subnet_id
  instance_count         = var.master_count
  storage_account        = azurerm_storage_account.cluster
  os_volume_type         = var.azure_master_root_volume_type
  os_volume_size         = var.azure_master_root_volume_size
  private                = module.vnet.private
  outbound_udr           = var.azure_outbound_user_defined_routing

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6
}

module "dns" {
  count                           = var.openshift_byo_dns ? 0 : 1
  source                          = "./dns"
  cluster_domain                  = "${var.cluster_name}.${var.base_domain}"
  cluster_id                      = local.cluster_id
  base_domain                     = var.base_domain
  virtual_network_id              = module.vnet.virtual_network_id
  external_lb_fqdn_v4             = module.vnet.public_lb_pip_v4_fqdn
  external_lb_fqdn_v6             = module.vnet.public_lb_pip_v6_fqdn
  internal_lb_ipaddress_v4        = module.vnet.internal_lb_ip_v4_address
  internal_lb_ipaddress_v6        = module.vnet.internal_lb_ip_v6_address
  resource_group_name             = data.azurerm_resource_group.main.name
  base_domain_resource_group_name = var.azure_base_domain_resource_group_name
  private                         = module.vnet.private

  use_ipv4                  = var.use_ipv4 || var.azure_emulate_single_stack_ipv6
  use_ipv6                  = var.use_ipv6
  emulate_single_stack_ipv6 = var.azure_emulate_single_stack_ipv6
}

resource "azurerm_resource_group" "main" {
  count = var.azure_resource_group_name == "" ? 1 : 0

  name     = "${local.cluster_id}-rg"
  location = var.azure_region
  tags     = local.tags
}

data "azurerm_resource_group" "main" {
  name = var.azure_resource_group_name == "" ? "${local.cluster_id}-rg" : var.azure_resource_group_name

  depends_on = [azurerm_resource_group.main]
}

data "azurerm_resource_group" "network" {
  count = var.azure_preexisting_network ? 1 : 0

  name = var.azure_network_resource_group_name
}

resource "azurerm_storage_account" "cluster" {
  name                     = "cluster${var.cluster_name}${random_string.cluster_id.result}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_user_assigned_identity" "main" {
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  name = "${local.cluster_id}-identity"
}

resource "azurerm_role_assignment" "main" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "network" {
  count = var.azure_preexisting_network ? 1 : 0

  scope                = data.azurerm_resource_group.network[0].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# copy over the vhd to cluster resource group and create an image using that
resource "azurerm_storage_container" "vhd" {
  name                 = "vhd"
  storage_account_name = azurerm_storage_account.cluster.name
}

resource "azurerm_storage_blob" "rhcos_image" {
  name                   = "rhcos${random_string.cluster_id.result}.vhd"
  storage_account_name   = azurerm_storage_account.cluster.name
  storage_container_name = azurerm_storage_container.vhd.name
  type                   = "Page"
  source_uri             = local.rhcos_image
  metadata               = tomap("source_uri", local.rhcos_image)
}

resource "azurerm_image" "cluster" {
  name                = local.cluster_id
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_region

  os_disk {
    os_type  = "Linux"
    os_state = "Generalized"
    blob_uri = azurerm_storage_blob.rhcos_image.url
  }
}

resource "null_resource" "delete_bootstrap" {
  depends_on = [
    module.master
  ]

  provisioner "local-exec" {
    command = <<EOF
./installer-files/openshift-install --dir=./installer-files wait-for bootstrap-complete --log-level=debug
az vm delete -g ${data.azurerm_resource_group.main.name} -n ${local.cluster_id}-bootstrap -y
az disk delete -g ${data.azurerm_resource_group.main.name} -n ${local.cluster_id}-bootstrap_OSDisk -y
az network public-ip delete -g ${data.azurerm_resource_group.main.name} -n ${local.cluster_id}-bootstrap-pip-v4
az network nic delete -g ${data.azurerm_resource_group.main.name} -n ${local.cluster_id}-bootstrap-nic
EOF    
  }
}
