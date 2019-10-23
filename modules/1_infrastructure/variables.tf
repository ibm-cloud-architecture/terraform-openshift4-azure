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

variable "dependson" {
  type    = list(string)
  default = []
}
