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
