resource "azurerm_storage_account" "ignition" {
  name                     = "ignition${local.cluster_nr}"
  resource_group_name      = var.resource_group_name
  location                 = var.azure_region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_storage_account_sas" "ignition" {
  connection_string = azurerm_storage_account.ignition.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start = "${timestamp()}"

  expiry = "${timeadd(timestamp(), "24h")}"

  permissions {
    read    = true
    list    = true
    create  = false
    add     = false
    delete  = false
    process = false
    write   = false
    update  = false
  }
}

resource "azurerm_storage_container" "ignition" {
  name                  = "ignition"
  storage_account_name  = azurerm_storage_account.ignition.name
  container_access_type = "private"
}

locals {
  installer_workspace     = "${path.root}/installer-files"
  openshift_installer_url = "${var.openshift_installer_url}/${var.openshift_version}"
  cluster_nr              = element(split("-", "${var.cluster_id}"), 1)
}

resource "null_resource" "download_binaries" {
  provisioner "local-exec" {
    when    = create
    command = <<EOF
test -e ${local.installer_workspace} || mkdir ${local.installer_workspace}
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
if [[ "${var.airgapped["enabled"]}" == "true" ]]; then ${local.installer_workspace}/oc adm release extract -a ${path.root}/${var.openshift_pull_secret} --command=openshift-install ${var.airgapped["repository"]}:${var.openshift_version}-x86_64 && mv ${path.root}/openshift-install ${local.installer_workspace};fi
EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${local.installer_workspace}"
  }

}


resource "null_resource" "generate_manifests" {
  triggers = {
    install_config = data.template_file.install_config_yaml.rendered
  }

  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
  ]

  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create manifests
#rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-*
#rm ${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-*
EOF
  }
}

# see templates.tf for generation of yaml config files

resource "null_resource" "generate_ignition" {
  depends_on = [
    null_resource.download_binaries,
    local_file.install_config_yaml,
    null_resource.generate_manifests,
    local_file.cluster-infrastructure-02-config,
    local_file.cluster-dns-02-config,
    local_file.cloud-provider-config,
    local_file.openshift-cluster-api_master-machines,
    local_file.openshift-cluster-api_worker-machineset,
    local_file.openshift-cluster-api_infra-machineset,
    #local_file.ingresscontroller-default,
    local_file.cloud-creds-secret-kube-system,
    #local_file.cluster-scheduler-02-config,
    local_file.cluster-monitoring-configmap,
    #local_file.private-cluster-outbound-service,
  ]

  provisioner "local-exec" {
    command = <<EOF
${local.installer_workspace}/openshift-install --dir=${local.installer_workspace} create ignition-configs
${local.installer_workspace}/jq '.infraID="${var.cluster_id}"' ${local.installer_workspace}/metadata.json > /tmp/metadata.json
mv /tmp/metadata.json ${local.installer_workspace}/metadata.json
EOF
  }
}

resource "azurerm_storage_blob" "ignition-bootstrap" {
  name                   = "bootstrap.ign"
  source                 = "${local.installer_workspace}/bootstrap.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-master" {
  name                   = "master.ign"
  source                 = "${local.installer_workspace}/master.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

resource "azurerm_storage_blob" "ignition-worker" {
  name                   = "worker.ign"
  source                 = "${local.installer_workspace}/worker.ign"
  storage_account_name   = azurerm_storage_account.ignition.name
  storage_container_name = azurerm_storage_container.ignition.name
  type                   = "Block"
  depends_on = [
    null_resource.generate_ignition
  ]
}

data "ignition_config" "master_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-master.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}

data "ignition_config" "bootstrap_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-bootstrap.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}

data "ignition_config" "worker_redirect" {
  replace {
    source = "${azurerm_storage_blob.ignition-worker.url}${data.azurerm_storage_account_sas.ignition.sas}"
  }
}