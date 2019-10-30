variable "azure_subscription_id" {
  type = string
}

variable "azure_client_id" {
  type = string
}

variable "azure_client_secret" {
  type = string
}

variable "azure_tenant_id" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "openshift_cluster_name" {
  type = string
}

variable "openshift_master_count" {
  type    = string
  default = 3
}

variable "openshift_worker_count" {
  type    = string
  default = 3
}

variable "machine_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azure_dns_resource_group_name" {
  type = string
}

variable "azure_master_vm_type" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "azure_bootstrap_vm_type" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "azure_worker_vm_type" {
  type    = string
  default = "Standard_D4s_v3"
}

variable "base_domain" {
  type = string
}

variable "openshift_cluster_network_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "openshift_cluster_network_host_prefix" {
  type    = string
  default = 23
}

variable "openshift_service_network_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "openshift_pull_secret" {
  type    = string
  default = "pull-secret"
}


variable "azure_master_root_volume_size" {
  type    = string
  default = 1024
}

variable "azure_worker_root_volume_size" {
  type    = string
  default = 128
}

# variable "azure_rhcos_image_id" {
#   type    = string
#   default = "/resourceGroups/rhcos_images/providers/Microsoft.Compute/images/rhcostestimage"
# }

# you can find the latest value in https://github.com/openshift/installer/blob/master/data/data/rhcos.json
variable "azure_rhcos_image_url" {
  type = string
  # default = "https://rhcos.blob.core.windows.net/imagebucket/rhcos-43.80.20191002.1-azure.x86_64.vhd"
  # default = "https://openshifttechpreview.blob.core.windows.net/rhcos/rhcos-410.8.20190504.0-azure.vhd"
  default = "https://rhcos.blob.core.windows.net/imagebucket/rhcos-42.80.20190823.0.vhd"
}

variable "bootstrap_complete" {
  type    = bool
  default = false
}

variable "openshift_version" {
  type    = string
  default = "latest"
}
