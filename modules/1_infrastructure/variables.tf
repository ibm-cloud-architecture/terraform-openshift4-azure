variable "cluster_id" {
  type = string
}
variable "azure_region" {
  type = string
}
variable "machine_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "master_count" {
  type = string
}

variable "worker_count" {
  type = string
}

variable "azure_image_url" {
  type = string
  # default = "https://openshifttechpreview.blob.core.windows.net/rhcos/rhcos-410.8.20190504.0-azure.vhd"
  default = "https://rhcos.blob.core.windows.net/imagebucket/rhcos-43.80.20191002.1-azure.x86_64.vhd"
}

variable "dependson" {
  type    = list(string)
  default = []
}

