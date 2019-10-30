
resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  installer_workspace = "${path.root}/installer-files"
}

resource "null_resource" "wait-for-bootstrap" {
  provisioner "local-exec" {
    command = "${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for bootstrap-complete --log-level debug"
  }

  depends_on = [
    "null_resource.dependency",
  ]
}

resource "null_resource" "update_ingress" {
  provisioner "local-exec" {
    command = <<EOF
while ! ${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig get ingresscontroller default -n openshift-ingress-operator > /dev/null 2>&1; do
  echo "waiting for default ingresscontroller"
  sleep 5;
done
echo "deleting default ingresscontroller"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig delete ingresscontroller default -n openshift-ingress-operator
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig create -f ${local.installer_workspace}/configs/99_default_ingress_controller.yaml
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig create -f ${local.installer_workspace}/configs/99_ingress-service-default.yaml
EOF
  }
  depends_on = [
    "null_resource.dependency",
    "null_resource.wait-for-bootstrap",
  ]
}

resource "null_resource" "update_storage" {
  provisioner "local-exec" {
    command = <<EOF
while ! ${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig get configs.imageregistry.operator.openshift.io cluster > /dev/null 2>&1; do
  echo "waiting for imageregistry"
  sleep 5;
done
echo "updating image registry storage"
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"defaultRoute":true}}'
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig adm policy add-cluster-role-to-user system:azure-cloud-provider-filestorage system:serviceaccount:kube-system:persistent-volume-binder
EOF
  }
  depends_on = [
    "null_resource.dependency",
    "null_resource.wait-for-bootstrap",
  ]
}

resource "null_resource" "install-cluster" {
  provisioner "local-exec" {
    command = "${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for install-complete --log-level debug"
  }

  depends_on = [
    "null_resource.dependency",
    "null_resource.update_ingress",
    "null_resource.update_storage",
    "null_resource.wait-for-bootstrap",
  ]
}
