variable "cluster_domain" {}

variable "dependson" {
  type    = list(string)
  default = []
}

variable "apps_external_lb_fqdn" {
  type = string
}

variable "cluster_external_lb_fqdn" {
  type = string
}

variable "internal_lb_ipaddress" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "azure_dns_resource_group_name" {
  type = string
}

variable "etcd_count" {
  type = string
}

variable "etcd_ip_addresses" {
  type = list(string)
}

variable "base_domain" {
  type = string
}

variable "vnet_id" {
  type = string
}
