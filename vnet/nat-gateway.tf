# variable "ssh_private_key" {
#   type = string
# }

# variable "ssh_public_key" {
#   type = string
# }

# locals {
#   gateway_subnet_cidr = cidrsubnet(var.vnet_cidr, 3, 2) #node subnet is a smaller subnet within the vnet. i.e from /21 to /24
#   ssh_private_key     = file("./installer-files/artifacts/openshift_rsa")
#   ssh_public_key      = file("./installer-files/artifacts/openshift_rsa")
# }

# resource "azurerm_public_ip" "nat_gateway_public_ip" {x
#   count = local.private ? 1 : 0

#   sku                 = "Standard"
#   location            = var.region
#   name                = "${var.cluster_id}-ngw"
#   resource_group_name = var.resource_group_name
#   allocation_method   = "Static"
#   domain_name_label   = "${var.dns_label}-ngw"
# }

# data "azurerm_public_ip" "nat_gateway_public_ip" {
#   count = local.private ? 1 : 0

#   name                = element(azurerm_public_ip.nat_gateway_public_ip.*.name, count.index)
#   resource_group_name = var.resource_group_name
# }

# resource "azurerm_subnet" "gateway_subnet" {
#   count = local.private ? 1 : 0

#   resource_group_name  = var.resource_group_name
#   address_prefix       = local.gateway_subnet_cidr
#   virtual_network_name = local.virtual_network
#   name                 = "${var.cluster_id}-gateway-subnet"
# }


# resource "azurerm_network_security_group" "gateway" {
#   count = local.private ? 1 : 0

#   name                = "${var.cluster_id}-gateway-nsg"
#   location            = var.region
#   resource_group_name = var.resource_group_name
# }

# resource "azurerm_subnet_network_security_group_association" "gateway" {
#   count = local.private ? 1 : 0

#   subnet_id                 = element(azurerm_subnet.gateway_subnet.*.id, count.index)
#   network_security_group_id = element(azurerm_network_security_group.gateway.*.id, count.index)
# }


# resource "azurerm_network_interface" "nat_gateway" {
#   count = local.private ? 1 : 0

#   name                 = "${var.cluster_id}-ngw-nic"
#   location             = var.region
#   resource_group_name  = var.resource_group_name
#   enable_ip_forwarding = true

#   ip_configuration {
#     subnet_id                     = element(azurerm_subnet.gateway_subnet.*.id, count.index)
#     name                          = "ngw-nic-ip"
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = element(azurerm_public_ip.nat_gateway_public_ip.*.id, count.index)
#   }
# }

# resource "azurerm_network_security_rule" "ssh_in" {
#   count = local.private ? 1 : 0

#   name                        = "ssh_in"
#   priority                    = 104
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_port_range           = "*"
#   destination_port_range      = "22"
#   source_address_prefix       = "*"
#   destination_address_prefix  = "*"
#   resource_group_name         = var.resource_group_name
#   network_security_group_name = element(azurerm_network_security_group.gateway.*.name, count.index)
# }

# resource "azurerm_network_security_rule" "private_to_public" {
#   count = local.private ? 1 : 0

#   name                        = "private_to_public"
#   priority                    = 105
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "*"
#   source_port_range           = "*"
#   destination_port_range      = "0-65535"
#   source_address_prefix       = "VirtualNetwork"
#   destination_address_prefix  = "*"
#   resource_group_name         = var.resource_group_name
#   network_security_group_name = element(azurerm_network_security_group.gateway.*.name, count.index)
# }

# resource "azurerm_virtual_machine" "nat_gateway" {
#   count = local.private ? 1 : 0

#   name                  = "${var.cluster_id}-ngw"
#   location              = var.region
#   resource_group_name   = var.resource_group_name
#   network_interface_ids = [element(azurerm_network_interface.nat_gateway.*.id, count.index)]
#   vm_size               = "Standard_D4s_v3"

#   delete_os_disk_on_termination    = true
#   delete_data_disks_on_termination = true

#   storage_os_disk {
#     name              = "${var.cluster_id}-ngw_OSDisk" # os disk name needs to match cluster-api convention
#     caching           = "ReadWrite"
#     create_option     = "FromImage"
#     managed_disk_type = "Premium_LRS"
#     disk_size_gb      = 100
#   }

#   storage_image_reference {
#     publisher = "Openlogic"
#     offer     = "CentOS"
#     sku       = "7.6"
#     version   = "latest"
#   }

#   os_profile {
#     computer_name  = "${var.cluster_id}-ngw-vm"
#     admin_username = "core"
#     admin_password = uuid()
#   }

#   os_profile_linux_config {
#     disable_password_authentication = true
#     ssh_keys {
#       path     = "/home/core/.ssh/authorized_keys"
#       key_data = local.ssh_public_key
#     }
#   }

#   connection {
#     host        = element(azurerm_public_ip.nat_gateway_public_ip.*.fqdn, count.index)
#     user        = "core"
#     port        = 22
#     private_key = local.ssh_private_key
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward",
#       "sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
#     ]
#   }
# }

# resource "azurerm_route" "internet" {
#   count = local.private ? 1 : 0

#   name                   = "internet"
#   resource_group_name    = var.resource_group_name
#   route_table_name       = azurerm_route_table.route_table.name
#   address_prefix         = "0.0.0.0/0"
#   next_hop_type          = "VirtualAppliance"
#   next_hop_in_ip_address = element(azurerm_network_interface.nat_gateway.*.private_ip_address, count.index)
# }

# resource "azurerm_subnet_route_table_association" "master" {
#   count = local.private ? 1 : 0

#   subnet_id      = local.master_subnet_id
#   route_table_id = azurerm_route_table.route_table.id
# }

# resource "azurerm_subnet_route_table_association" "worker" {
#   count = local.private ? 1 : 0

#   subnet_id      = local.worker_subnet_id
#   route_table_id = azurerm_route_table.route_table.id
# }

# output "nat_gateway_public_ip" {
#   value = local.private == false ? null : azurerm_public_ip.nat_gateway_public_ip[0].ip_address
# }
