resource "null_resource" "dependency" {
  triggers = {
    all_dependencies = "${join(",", var.dependson)}"
  }
}

locals {
  installer_workspace     = "${path.root}/installer-files"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}"
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when    = "create"
    command = <<EOF
mkdir ${local.installer_workspace}
case $(uname -s) in
  Darwin)
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-install-mac-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-install-mac-4*.tar.gz -C ${local.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-client-mac-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-client-mac-4*.tar.gz -C ${local.installer_workspace}
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -O ${local.installer_workspace}/jq > /dev/null 2>&1\
    ;;
  Linux)
    wget -r -l1 -np -nd -q ${local.installer_workspace} -P ${local.installer_workspace} -A 'openshift-install-linux-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-install-linux-4*.tar.gz -C ${local.installer_workspace}
    wget -r -l1 -np -nd -q ${local.openshift_installer_url} -P ${local.installer_workspace} -A 'openshift-client-linux-4*.tar.gz'
    tar zxvf ${local.installer_workspace}/openshift-client-linux-4*.tar.gz -C ${local.installer_workspace}
    wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O ${local.installer_workspace}/jq
    ;;
  *)
    exit 1;;
esac
chmod u+x ${local.installer_workspace}/jq
rm -f ${local.installer_workspace}/*.tar.gz ${local.installer_workspace}/robots*.txt* ${local.installer_workspace}/README.md
EOF
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "rm -rf ${local.installer_workspace}"
  }

  depends_on = [
    "null_resource.dependency",
  ]
}


resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = "${data.template_file.install_config_yaml.rendered}"
  }

  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "local_file.install_config_yaml",
  ]

  provisioner "local-exec" {
    command = "${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create manifests"
  }
}

# see templates.tf for generation of yaml config files

resource "null_resource" "generate_ignition" {
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "local_file.install_config_yaml",
    "null_resource.generate_manifests",
    "local_file.cluster-infrastructure-02-config",
    "local_file.cluster-dns-02-config",
    "local_file.cloud-provider-config",
    "local_file.etcd-host-service-endpoints",
    "local_file.openshift-cluster-api_master-machines",
    "local_file.openshift-cluster-api_worker-machineset",
    "local_file.openshift-cluster-api_infra-machineset",
    "local_file.ingresscontroller-default",
    "local_file.ingress-service-default",
    "local_file.cloud-creds-secret-kube-system",
    "local_file.cluster-scheduler-02-config",
    "local_file.cluster-monitoring-configmap",
  ]

  provisioner "local-exec" {
    command = <<EOF
rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-*
# rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-*
cp -Rp ${local.installer_workspace}/openshift/ ${local.installer_workspace}/_openshift/
cp -Rp ${local.installer_workspace}/manifests/ ${local.installer_workspace}/_manifests/
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create ignition-configs
${local.installer_workspace}/jq '.infraID="${var.cluster_id}"' ${local.installer_workspace}/metadata.json > /tmp/metadata.json
mv /tmp/metadata.json ${local.installer_workspace}/metadata.json
EOF
  }
}

resource "azurerm_storage_blob" "ignition-bootstrap" {
  name                   = "bootstrap.ign"
  source                 = "${local.installer_workspace}/bootstrap.ign"
  resource_group_name    = "${var.resource_group_name}"
  storage_account_name   = "${var.storage_account_name}"
  storage_container_name = "${var.storage_container_name}"
  type                   = "block"
  depends_on = [
    "null_resource.generate_ignition"
  ]
}

resource "azurerm_storage_blob" "ignition-master" {
  name                   = "master.ign"
  source                 = "${local.installer_workspace}/master.ign"
  resource_group_name    = "${var.resource_group_name}"
  storage_account_name   = "${var.storage_account_name}"
  storage_container_name = "${var.storage_container_name}"
  type                   = "block"
  depends_on = [
    "null_resource.generate_ignition"
  ]
}

resource "azurerm_storage_blob" "ignition-worker" {
  name                   = "worker.ign"
  source                 = "${local.installer_workspace}/worker.ign"
  resource_group_name    = "${var.resource_group_name}"
  storage_account_name   = "${var.storage_account_name}"
  storage_container_name = "${var.storage_container_name}"
  type                   = "block"
  depends_on = [
    "null_resource.generate_ignition"
  ]
}

data "ignition_config" "master_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-master.url}${var.storage_account_sas}"
  }
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-bootstrap.url}${var.storage_account_sas}"
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-worker.url}${var.storage_account_sas}"
  }
}
