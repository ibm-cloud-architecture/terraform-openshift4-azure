variable "vnet_cidr" {
  type = string
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the deployment"
}

variable "cluster_id" {
  type = string
}

variable "region" {
  type        = string
  description = "The target Azure region for the cluster."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Azure tags to be applied to created resources."
}

variable "dns_label" {
  type        = string
  description = "The label used to build the dns name. i.e. <label>.<region>.cloudapp.azure.com"
}

variable "private" {
  type        = bool
  description = "The determines if this is a private/internal cluster or not."
}

variable "airgapped" {
  type = map(string)
  default = {
    enabled = false
  }
}
