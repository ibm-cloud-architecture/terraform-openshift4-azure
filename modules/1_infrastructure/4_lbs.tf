locals {
  internal_lb_frontend_ip_configuration_name = "internal-lb-ip"
  public_lb_frontend_ip_configuration_name   = "public-lb-ip"
  app_lb_frontend_ip_configuration_name      = "app-lb-ip"
  // The name of the masters' ipconfiguration is hardcoded to "pipconfig". It needs to match cluster-api
  // https://github.com/openshift/cluster-api-provider-azure/blob/master/pkg/cloud/azure/services/networkinterfaces/networkinterfaces.go#L180
  ip_configuration_name               = "pipConfig"
  bootstrap_nic_ip_configuration_name = "bootstrap-nic-ip"

}

resource "azurerm_lb" "controlplane_internal" {
  sku                 = "Standard"
  name                = "${var.cluster_id}-internal-lb"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"

  frontend_ip_configuration {
    name                          = "${local.internal_lb_frontend_ip_configuration_name}"
    subnet_id                     = "${azurerm_subnet.master_subnet.id}"
    private_ip_address_allocation = "Static"
    private_ip_address            = "${cidrhost(local.master_subnet_cidr, -2)}" #last ip is reserved by azure
  }
}

resource "azurerm_lb_backend_address_pool" "internal_lb_controlplane_pool" {
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  loadbalancer_id     = "${azurerm_lb.controlplane_internal.id}"
  name                = "${var.cluster_id}-internal-controlplane"
}

resource "azurerm_lb_rule" "internal_lb_rule_api_internal" {
  name                           = "api-internal"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
  loadbalancer_id                = "${azurerm_lb.controlplane_internal.id}"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "${local.internal_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.internal_lb_probe_api_internal.id}"
}

resource "azurerm_lb_rule" "internal_lb_rule_sint" {
  name                           = "sint"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
  loadbalancer_id                = "${azurerm_lb.controlplane_internal.id}"
  frontend_port                  = 22623
  backend_port                   = 22623
  frontend_ip_configuration_name = "${local.internal_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.internal_lb_probe_sint.id}"
}

resource "azurerm_lb_probe" "internal_lb_probe_sint" {
  name                = "sint-probe"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.controlplane_internal.id}"
  port                = 22623
  request_path        = "/healthz"
  protocol            = "Https"
}

resource "azurerm_lb_probe" "internal_lb_probe_api_internal" {
  name                = "api-internal-probe"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.controlplane_internal.id}"
  port                = 6443
  request_path        = "/readyz"
  protocol            = "Https"
}

resource "azurerm_public_ip" "cluster_public_ip" {
  sku                 = "Standard"
  location            = "${var.azure_region}"
  name                = "${var.cluster_id}-pip"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  allocation_method   = "Static"
  domain_name_label   = "${var.cluster_id}"
}

data "azurerm_public_ip" "cluster_public_ip" {
  name                = "${azurerm_public_ip.cluster_public_ip.name}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
}

resource "azurerm_public_ip" "worker_public_ip" {
  sku                 = "Standard"
  location            = "${var.azure_region}"
  name                = "apps-${var.cluster_id}-pip"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  allocation_method   = "Static"
  domain_name_label   = "apps-${var.cluster_id}"
}

data "azurerm_public_ip" "worker_public_ip" {
  name                = "${azurerm_public_ip.worker_public_ip.name}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
}

resource "azurerm_lb" "controlplane_public" {
  sku                 = "Standard"
  name                = "${var.cluster_id}-public-lb"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"

  frontend_ip_configuration {
    name                 = "${local.public_lb_frontend_ip_configuration_name}"
    public_ip_address_id = "${azurerm_public_ip.cluster_public_ip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "master_public_lb_pool" {
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  loadbalancer_id     = "${azurerm_lb.controlplane_public.id}"
  name                = "${var.cluster_id}-public-lb-control-plane"
}

resource "azurerm_lb_rule" "public_lb_rule_api_internal" {
  name                           = "api-internal"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master_public_lb_pool.id}"
  loadbalancer_id                = "${azurerm_lb.controlplane_public.id}"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "${local.public_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.public_lb_probe_api_internal.id}"
}

resource "azurerm_lb_rule" "public_lb_rule_sint_internal" {
  name                           = "sint-internal"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master_public_lb_pool.id}"
  loadbalancer_id                = "${azurerm_lb.controlplane_public.id}"
  frontend_port                  = 22623
  backend_port                   = 22623
  frontend_ip_configuration_name = "${local.public_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.public_lb_sint.id}"
}

resource "azurerm_lb_probe" "public_lb_probe_api_internal" {
  name                = "api-internal-probe"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.controlplane_public.id}"
  port                = 6443
  protocol            = "TCP"
}

resource "azurerm_lb_probe" "public_lb_sint" {
  name                = "sint-probe"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.controlplane_public.id}"
  port                = 22623
  protocol            = "TCP"
}


resource "azurerm_lb" "worker_public" {
  sku                 = "Standard"
  name                = "${var.cluster_id}-apps-lb"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${var.azure_region}"

  frontend_ip_configuration {
    name                 = "${local.app_lb_frontend_ip_configuration_name}"
    public_ip_address_id = "${azurerm_public_ip.worker_public_ip.id}"
  }
}


resource "azurerm_lb_backend_address_pool" "worker_public_lb_pool" {
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  loadbalancer_id     = "${azurerm_lb.worker_public.id}"
  name                = "${var.cluster_id}-apps-lb-routers"
}

resource "azurerm_lb_rule" "public_lb_rule_http" {
  name                           = "tcp-80"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.worker_public_lb_pool.id}"
  loadbalancer_id                = "${azurerm_lb.worker_public.id}"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${local.app_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.public_lb_http.id}"
}

resource "azurerm_lb_rule" "public_lb_rule_https" {
  name                           = "tcp-443"
  resource_group_name            = "${azurerm_resource_group.openshift.name}"
  protocol                       = "Tcp"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.worker_public_lb_pool.id}"
  loadbalancer_id                = "${azurerm_lb.worker_public.id}"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "${local.app_lb_frontend_ip_configuration_name}"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = "${azurerm_lb_probe.public_lb_http.id}"
}

resource "azurerm_lb_probe" "public_lb_http" {
  name                = "probe-http"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.worker_public.id}"
  port                = 80
  protocol            = "TCP"
}

resource "azurerm_lb_probe" "public_lb_https" {
  name                = "probe-https"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  interval_in_seconds = 10
  number_of_probes    = 3
  loadbalancer_id     = "${azurerm_lb.worker_public.id}"
  port                = 443
  protocol            = "TCP"
}

# MASTER VM NETWORKING
resource "azurerm_network_interface" "master" {
  count               = "${var.master_count}"
  name                = "${var.cluster_id}-master${count.index}-nic"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"

  ip_configuration {
    subnet_id                     = "${azurerm_subnet.master_subnet.id}"
    name                          = "${local.ip_configuration_name}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "master" {
  count                   = "${var.master_count}"
  network_interface_id    = "${element(azurerm_network_interface.master.*.id, count.index)}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.master_public_lb_pool.id}"
  ip_configuration_name   = "${local.ip_configuration_name}" #must be the same as nic's ip configuration name.
}

# resource "azurerm_network_interface_backend_address_pool_association" "master_internal" {
#   count                   = "${var.master_count}"
#   network_interface_id    = "${element(azurerm_network_interface.master.*.id, count.index)}"
#   backend_address_pool_id = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
#   ip_configuration_name   = "${local.ip_configuration_name}" #must be the same as nic's ip configuration name.
# }

# BOOTSTRAP VM NETWORKING
resource "azurerm_public_ip" "bootstrap_public_ip" {
  sku                 = "Standard"
  location            = "${var.azure_region}"
  name                = "${var.cluster_id}-bootstrap-pip"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "bootstrap" {
  name                = "${var.cluster_id}-bootstrap-nic"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.openshift.name}"

  ip_configuration {
    subnet_id                     = "${azurerm_subnet.master_subnet.id}"
    name                          = "${local.bootstrap_nic_ip_configuration_name}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bootstrap_public_ip.id}"
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "public_lb_bootstrap" {
  network_interface_id    = "${azurerm_network_interface.bootstrap.id}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.master_public_lb_pool.id}"
  ip_configuration_name   = "${local.bootstrap_nic_ip_configuration_name}"
}

resource "azurerm_network_interface_backend_address_pool_association" "internal_lb_bootstrap" {
  network_interface_id    = "${azurerm_network_interface.bootstrap.id}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.internal_lb_controlplane_pool.id}"
  ip_configuration_name   = "${local.bootstrap_nic_ip_configuration_name}"
}


# WORKER VM NETWORKING
resource "azurerm_network_interface" "worker" {
  count               = "${var.worker_count}"
  name                = "${var.cluster_id}-worker${count.index}-nic"
  location            = "${var.azure_region}"
  resource_group_name = "${var.cluster_id}-rg"

  ip_configuration {
    subnet_id                     = "${azurerm_subnet.node_subnet.id}"
    name                          = "${local.ip_configuration_name}"
    private_ip_address_allocation = "Dynamic"
  }
}

# resource "azurerm_network_interface_backend_address_pool_association" "worker" {
#   count                   = "${var.worker_count}"
#   network_interface_id    = "${element(azurerm_network_interface.worker.*.id, count.index)}"
#   backend_address_pool_id = "${azurerm_lb_backend_address_pool.worker_public_lb_pool.id}"
#   ip_configuration_name   = "${local.ip_configuration_name}" #must be the same as nic's ip configuration name.
# }
