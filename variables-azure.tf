variable "azure_config_version" {
  description = <<EOF
(internal) This declares the version of the Azure configuration variables.
It has no impact on generated assets but declares the version contract of the configuration.
EOF


  default = "0.1"
}

variable "azure_region" {
  type        = string
  description = "The target Azure region for the cluster."
}

variable "azure_bootstrap_vm_type" {
  type        = string
  description = "Instance type for the bootstrap node. Example: `Standard_DS4_v3`."
  default     = "Standard_D4s_v3"
}

variable "azure_master_vm_type" {
  type        = string
  description = "Instance type for the master node(s). Example: `Standard_DS4_v3`."
  default     = "Standard_D4s_v3"
}

variable "azure_extra_tags" {
  type = map(string)

  description = <<EOF
(optional) Extra Azure tags to be applied to created resources.

Example: `{ "key" = "value", "foo" = "bar" }`
EOF


  default = {}
}

variable "azure_master_root_volume_type" {
  type        = string
  description = "The type of the volume the root block device of master nodes."
  default     = "Premium_LRS"
}

variable "azure_master_root_volume_size" {
  type        = string
  description = "The size of the volume in gigabytes for the root block device of master nodes."
  default     = 1024
}

variable "azure_base_domain_resource_group_name" {
  type        = string
  description = "The resource group that contains the dns zone used as base domain for the cluster."
}

variable "azure_image_url" {
  type        = string
  description = "The URL of the vm image used for all nodes."
  default     = "https://rhcos.blob.core.windows.net/imagebucket/rhcos-42.80.20191002.0.vhd"
}

variable "azure_subscription_id" {
  type        = string
  description = "The subscription that should be used to interact with Azure API"
}

variable "azure_client_id" {
  type        = string
  description = "The app ID that should be used to interact with Azure API"
}

variable "azure_client_secret" {
  type        = string
  description = "The password that should be used to interact with Azure API"
}

variable "azure_tenant_id" {
  type        = string
  description = "The tenant ID that should be used to interact with Azure API"
}

#################################################

variable "cluster_name" {
  type = string
}

variable "machine_cidr" {
  type    = string
  default = "10.0.0.0/16"
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

variable "azure_infra_root_volume_size" {
  type    = string
  default = 128
}

variable "azure_worker_root_volume_size" {
  type    = string
  default = 128
}

variable "openshift_master_count" {
  type    = string
  default = 3
}

variable "openshift_worker_count" {
  type    = string
  default = 3
}

variable "openshift_infra_count" {
  type    = string
  default = 0
}

variable "azure_infra_vm_type" {
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

variable "openshift_version" {
  type    = string
  default = "latest"
}

variable "bootstrap_completed" {
  type    = bool
  default = false
}

variable "airgapped" {
  type = map(string)
  default = {
    airgapped     = false
    repository    = ""
    create_egress = false
  }
}
