
resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  installer_workspace = "${path.root}/installer-files"
}

resource "null_resource" "install-cluster" {
  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for bootstrap-complete --log-level debug
while ! ${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig get configs.imageregistry.operator.openshift.io cluster > /dev/null 2>&1; do
  echo "waiting for cluster"
  sleep 5;
done
echo "patching image registry storage"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'
echo "patching image registry route"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"defaultRoute":true}}'
echo "adding user to cluster role"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig adm policy add-cluster-role-to-user system:azure-cloud-provider-filestorage system:serviceaccount:kube-system:persistent-volume-binder
echo "deleting default ingresscontroller"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig delete ingresscontroller default -n openshift-ingress-operator
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig create -f ${local.installer_workspace}/configs/99_default_ingress_controller.yaml
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig create -f ${local.installer_workspace}/configs/99_ingress-service-default.yaml
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for install-complete --log-level debug
EOF
  }

  depends_on = [
    "null_resource.dependency",
  ]
}


# Enable when azurerm_image allows hyperVGeneration variable
# resource "azurerm_image" "rhcosimage" {
#   count               = 0
#   name                = var.cluster_id
#   location            = var.azure_region
#   resource_group_name = var.resource_group_name

#   os_disk {
#     os_type  = "Linux"
#     blob_uri = var.image_url
#   }
#   depends_on = [
#     "null_resource.install-cluster"
#   ]
# }
