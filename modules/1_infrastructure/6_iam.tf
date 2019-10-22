resource "azurerm_user_assigned_identity" "main" {
  name                = "${var.cluster_id}-identity"
  resource_group_name = "${azurerm_resource_group.openshift.name}"
  location            = "${azurerm_resource_group.openshift.location}"
}

resource "azurerm_role_assignment" "contributor" {
  scope                = "${azurerm_resource_group.openshift.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azurerm_user_assigned_identity.main.principal_id}"
}

resource "azurerm_role_assignment" "user_access_administrator" {
  scope                = "${azurerm_resource_group.openshift.id}"
  role_definition_name = "User Access Administrator"
  principal_id         = "${azurerm_user_assigned_identity.main.principal_id}"
}
