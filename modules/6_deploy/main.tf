
resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  installer_workspace =  "${path.root}/installer-files"
}

resource "null_resource" "install-cluster" {
  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for bootstrap-complete --log-level debug
while ! ${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig get configs.imageregistry.operator.openshift.io cluster ; do
    sleep 2;
done
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"storage":{"pvc":{"claim":""}}}}'
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig patch configs.imageregistry.operator.openshift.io cluster --type merge --patch '{"spec":{"defaultRoute":true}}'
${local.installer_workspace}/oc --config=${local.installer_workspace}/auth/kubeconfig adm policy add-cluster-role-to-user system:azure-cloud-provider-filestorage system:serviceaccount:kube-system:persistent-volume-binder
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} wait-for install-complete --log-level debug
EOF
  }

  depends_on = [
    "null_resource.dependency"
  ]
}
