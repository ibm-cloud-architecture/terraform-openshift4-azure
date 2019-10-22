variable "azure_region" {
  type = "string"
}

variable "boot_diag_blob_endpoint" {
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

variable "instance_count" {
  type = "string"
}

variable "ignition" {
  type = "string"
}

variable "network_intreface_id" {
  type = "list"
}

variable "vm_size" {
  type = "string"
}

variable "os_volume_size" {
  type = "string"
}

variable "resource_group_name" {
  type = "string"
}

variable "vm_image" {
  type = "string"
}

variable "node_type" {
  type = "string"
}