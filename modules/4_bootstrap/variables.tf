variable "boot_diag_blob_endpoint" {
  type = "string"
}

variable "network_interface_id" {
  type = "string"
}

variable "cluster_id" {
  type = "string"
}

variable "dependson" {
  type = "list"
  default = []
}

variable "identity" {
  type = "string"
}

variable "ignition" {
  type = "string"
}

variable "nsg_name" {
  type = "string"
}

variable "azure_region" {
  type = "string"
}

variable "resource_group_name" {
  type = "string"
}

variable "vm_image" {
  type = "string"
}

variable "vm_size" {
  type = "string"
}
