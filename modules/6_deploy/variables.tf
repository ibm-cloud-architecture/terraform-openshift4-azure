variable "dependson" {
  type    = list(string)
  default = []
}


variable "cluster_id" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "image_url" {
  type    = string
  default = "https://openshifttechpreview.blob.core.windows.net/rhcos/rhcos-410.8.20190504.0-azure.vhd"
}
