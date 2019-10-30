data "template_file" "install_config_yaml" {
  template = <<EOF
apiVersion: v1
baseDomain: ${var.base_domain}
compute:
- hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: ${var.node_count}
controlPlane:
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: ${var.master_count}
metadata:
  creationTimestamp: null
  name: ${var.cluster_name}
networking:
  clusterNetwork:
  - cidr: ${var.cluster_network_cidr}
    hostPrefix: ${var.cluster_network_host_prefix}
  machineCIDR: ${var.machine_cidr}
  networkType: OpenShiftSDN
  serviceNetwork:
  - ${var.service_network_cidr}
platform:
  azure:
    baseDomainResourceGroupName: ${var.azure_dns_resource_group_name}
    region: ${var.azure_region}
pullSecret: '${var.openshift_pull_secret}'
sshKey: '${var.public_ssh_key}'  
EOF
}

resource "local_file" "install_config_yaml" {
  content  = "${data.template_file.install_config_yaml.rendered}"
  filename = "${local.installer_workspace}/install-config.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
  ]
}

data "template_file" "cluster-infrastructure-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Infrastructure
metadata:
  creationTimestamp: null
  name: cluster
spec:
  cloudConfig:
    key: config
    name: cloud-provider-config
status:
  apiServerInternalURI: https://api-int.${var.cluster_name}.${var.base_domain}:6443
  apiServerURL: https://api.${var.cluster_name}.${var.base_domain}:6443
  etcdDiscoveryDomain: ${var.cluster_name}.${var.base_domain}
  infrastructureName: ${var.cluster_id}
  platform: Azure
  platformStatus:
    azure:
      resourceGroupName: ${var.cluster_id}-rg
    type: Azure
EOF
}

resource "local_file" "cluster-infrastructure-02-config" {
  content  = data.template_file.cluster-infrastructure-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-infrastructure-02-config.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "cluster-dns-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: DNS
metadata:
  creationTimestamp: null
  name: cluster
spec:
  baseDomain: ${var.cluster_name}.${var.base_domain}
  privateZone:
    id: /subscriptions/${var.azure_subscription_id}/resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Network/dnszones/${var.cluster_name}.${var.base_domain}
  publicZone:
    id: /subscriptions/${var.azure_subscription_id}/resourceGroups/${var.azure_dns_resource_group_name}/providers/Microsoft.Network/dnszones/${var.base_domain}
status: {}
EOF
}

resource "local_file" "cluster-dns-02-config" {
  content  = data.template_file.cluster-dns-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-dns-02-config.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "cloud-provider-config" {
  template = <<EOF
apiVersion: v1
data:
  config: "{\n\t\"cloud\": \"AzurePublicCloud\",\n\t\"tenantId\": \"${var.azure_tenant_id}\",\n\t\"aadClientId\":
    \"\",\n\t\"aadClientSecret\": \"\",\n\t\"aadClientCertPath\": \"\",\n\t\"aadClientCertPassword\":
    \"\",\n\t\"useManagedIdentityExtension\": true,\n\t\"userAssignedIdentityID\":
    \"\",\n\t\"subscriptionId\": \"${var.azure_subscription_id}\",\n\t\"resourceGroup\":
    \"${var.cluster_id}-rg\",\n\t\"location\": \"${var.azure_region}\",\n\t\"vnetName\": \"${var.worker_vnet_name}\",\n\t\"vnetResourceGroup\":
    \"${var.cluster_id}-rg\",\n\t\"subnetName\": \"${var.cluster_id}-node-subnet\",\n\t\"securityGroupName\":
    \"${var.cluster_id}-node-nsg\",\n\t\"routeTableName\": \"${var.cluster_id}-node-routetable\",\n\t\"primaryAvailabilitySetName\":
    \"\",\n\t\"vmType\": \"\",\n\t\"primaryScaleSetName\": \"\",\n\t\"cloudProviderBackoff\":
    true,\n\t\"cloudProviderBackoffRetries\": 0,\n\t\"cloudProviderBackoffExponent\":
    0,\n\t\"cloudProviderBackoffDuration\": 6,\n\t\"cloudProviderBackoffJitter\":
    0,\n\t\"cloudProviderRateLimit\": true,\n\t\"cloudProviderRateLimitQPS\": 6,\n\t\"cloudProviderRateLimitBucket\":
    10,\n\t\"cloudProviderRateLimitQPSWrite\": 6,\n\t\"cloudProviderRateLimitBucketWrite\":
    10,\n\t\"useInstanceMetadata\": true,\n\t\"loadBalancerSku\": \"standard\",\n\t\"excludeMasterFromStandardLB\":
    null,\n\t\"disableOutboundSNAT\": null,\n\t\"maximumLoadBalancerRuleCount\": 0\n}\n"
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: cloud-provider-config
  namespace: openshift-config
EOF
}

resource "local_file" "cloud-provider-config" {
  content  = data.template_file.cloud-provider-config.rendered
  filename = "${local.installer_workspace}/manifests/cloud-provider-config.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "etcd-host-service-endpoints-addresses" {
  count    = var.master_count
  template = <<EOF
  - ip: ${element(var.etcd_ip_addresses, count.index)}
    hostname: etcd-${count.index}
EOF
}

data "template_file" "etcd-host-service-endpoints" {
  template = <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: host-etcd
  namespace: openshift-etcd
  annotations:
    alpha.installer.openshift.io/dns-suffix: ocp42.azure.ncolon.xyz
subsets:
- addresses:
${join("", data.template_file.etcd-host-service-endpoints-addresses.*.rendered)}
  ports:
  - name: etcd
    port: 2379
    protocol: TCP
EOF
}

resource "local_file" "etcd-host-service-endpoints" {
  content  = data.template_file.etcd-host-service-endpoints.rendered
  filename = "${local.installer_workspace}/manifests/etcd-host-service-endpoints.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "openshift-cluster-api_master-machines" {
  count    = var.master_count
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: Machine
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: master
    machine.openshift.io/cluster-api-machine-type: master
  name: ${var.cluster_id}-master-${count.index}
  namespace: openshift-machine-api
spec:
  metadata:
    creationTimestamp: null
  providerSpec:
    value:
      apiVersion: azureproviderconfig.openshift.io/v1beta1
      credentialsSecret:
        name: azure-cloud-credentials
        namespace: openshift-machine-api
      image:
        offer: ""
        publisher: ""
        resourceID: /resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Compute/images/${var.cluster_id}
        sku: ""
        version: ""
      internalLoadBalancer: ""
      kind: AzureMachineProviderSpec
      location: ${var.azure_region}
      managedIdentity: ${var.cluster_id}-identity
      metadata:
        creationTimestamp: null
      natRule: null
      networkResourceGroup: ${var.cluster_id}-rg
      osDisk:
        diskSizeGB: ${var.master_os_disk_size}
        managedDisk:
          storageAccountType: Premium_LRS
        osType: Linux
      publicIP: false
      publicLoadBalancer: ""
      resourceGroup: ${var.cluster_id}-rg
      sshPrivateKey: ""
      sshPublicKey: ""
      subnet: ${var.cluster_id}-master-subnet
      userDataSecret:
        name: master-user-data
      vmSize: ${var.master_vm_type}
      vnet: ${var.controlplane_vnet_name}
      zone: "${count.index + 1}"
status: {}
EOF
}

resource "local_file" "openshift-cluster-api_master-machines" {
  count    = var.master_count
  content  = element(data.template_file.openshift-cluster-api_master-machines.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_master-machines-${count.index}.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "openshift-cluster-api_worker-machineset" {
  count    = "${var.node_count}"
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-worker-${var.azure_region}${count.index + 1}
    spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: ""
            publisher: ""
            resourceID: /resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Compute/images/${var.cluster_id}
            sku: ""
            version: ""
          internalLoadBalancer: ""
          kind: AzureMachineProviderSpec
          location: ${var.azure_region}
          managedIdentity: ${var.cluster_id}-identity
          metadata:
            creationTimestamp: null
          natRule: null
          networkResourceGroup: ${var.cluster_id}-rg
          osDisk:
            diskSizeGB: ${var.worker_os_disk_size}
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: ""
          resourceGroup: ${var.cluster_id}-rg
          sshPrivateKey: ""
          sshPublicKey: ""
          subnet: ${var.cluster_id}-worker-subnet
          userDataSecret:
            name: worker-user-data
          vmSize: ${var.worker_vm_type}
          vnet: ${var.worker_vnet_name}
          zone: "${count.index + 1}"
status:
  replicas: 0
EOF
}

resource "local_file" "openshift-cluster-api_worker-machineset" {
  count    = var.node_count
  content  = element(data.template_file.openshift-cluster-api_worker-machineset.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_worker-machineset-${count.index}.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "openshift-cluster-api_infra-machineset" {
  count    = "${var.infra_count}"
  template = <<EOF
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: null
  labels:
    machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
    machine.openshift.io/cluster-api-machine-role: infra
    machine.openshift.io/cluster-api-machine-type: infra
  name: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
      machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: ${var.cluster_id}
        machine.openshift.io/cluster-api-machine-role: infra
        machine.openshift.io/cluster-api-machine-type: infra
        machine.openshift.io/cluster-api-machineset: ${var.cluster_id}-infra-${var.azure_region}${count.index + 1}
    spec:
      metadata:
        creationTimestamp: null
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          apiVersion: azureproviderconfig.openshift.io/v1beta1
          credentialsSecret:
            name: azure-cloud-credentials
            namespace: openshift-machine-api
          image:
            offer: ""
            publisher: ""
            resourceID: /resourceGroups/${var.cluster_id}-rg/providers/Microsoft.Compute/images/${var.cluster_id}
            sku: ""
            version: ""
          internalLoadBalancer: ""
          kind: AzureMachineProviderSpec
          location: ${var.azure_region}
          managedIdentity: ${var.cluster_id}-identity
          metadata:
            creationTimestamp: null
          natRule: null
          networkResourceGroup: ${var.cluster_id}-rg
          osDisk:
            diskSizeGB: ${var.infra_os_disk_size}
            managedDisk:
              storageAccountType: Premium_LRS
            osType: Linux
          publicIP: false
          publicLoadBalancer: ""
          resourceGroup: ${var.cluster_id}-rg
          sshPrivateKey: ""
          sshPublicKey: ""
          subnet: ${var.cluster_id}-worker-subnet
          userDataSecret:
            name: worker-user-data
          vmSize: ${var.infra_vm_type}
          vnet: ${var.worker_vnet_name}
          zone: "${count.index + 1}"
EOF
}

resource "local_file" "openshift-cluster-api_infra-machineset" {
  count    = var.infra_count
  content  = element(data.template_file.openshift-cluster-api_infra-machineset.*.rendered, count.index)
  filename = "${local.installer_workspace}/openshift/99_openshift-cluster-api_infra-machineset-${count.index}.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "ingresscontroller-default" {
  template = <<EOF
apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  finalizers:
  - ingresscontroller.operator.openshift.io/finalizer-ingresscontroller
  name: default
  namespace: openshift-ingress-operator
spec:
  endpointPublishingStrategy:
    type: LoadBalanceService
  replicas: 2
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
EOF
}


resource "local_file" "ingresscontroller-default" {
  content  = data.template_file.ingresscontroller-default.rendered
  filename = "${local.installer_workspace}/configs/99_default_ingress_controller.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "ingress-service-default" {
  template = <<EOF
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-resource-group: ${var.resource_group_name}
  name: azure-load-balancer
  namespace: openshift-ingress
spec:
  loadBalancerIP: ${var.apps_lb_pip_ip}
  type: LoadBalancer
  ports:
  - port: 80
    name: http
  - port: 443
    name: https
  selector:
    ingresscontroller.operator.openshift.io/deployment-ingresscontroller: default
EOF
}

resource "local_file" "ingress-service-default" {
  content  = data.template_file.ingress-service-default.rendered
  filename = "${local.installer_workspace}/configs/99_ingress-service-default.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "cloud-creds-secret-kube-system" {
  template = <<EOF
kind: Secret
apiVersion: v1
metadata:
  namespace: kube-system
  name: azure-credentials
data:
  azure_subscription_id: ${base64encode(var.azure_subscription_id)}
  azure_client_id: ${base64encode(var.azure_client_id)}
  azure_client_secret: ${base64encode(var.azure_client_secret)}
  azure_tenant_id: ${base64encode(var.azure_tenant_id)}
  azure_resource_prefix: ${base64encode(var.cluster_id)}
  azure_resourcegroup: ${base64encode("${var.cluster_id}-rg")}
  azure_region: ${base64encode(var.azure_region)}
EOF
}

resource "local_file" "cloud-creds-secret-kube-system" {
  content  = data.template_file.cloud-creds-secret-kube-system.rendered
  filename = "${local.installer_workspace}/openshift/99_cloud-creds-secret.yaml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "cluster-scheduler-02-config" {
  template = <<EOF
apiVersion: config.openshift.io/v1
kind: Scheduler
metadata:
  creationTimestamp: null
  name: cluster
spec:
  mastersSchedulable: false
  policy:
    name: ""
status: {}
EOF
}

resource "local_file" "cluster-scheduler-02-config" {
  content  = data.template_file.cluster-scheduler-02-config.rendered
  filename = "${local.installer_workspace}/manifests/cluster-scheduler-02-config.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "azure-storage-clusterrole" {
  template = <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:azure-cloud-provider-filestorage
rules:
- apiGroups: ['']
  resources: ['secrets']
  verbs:     ['get','create']
EOF
}

resource "local_file" "azure-storage-clusterrole" {
  content  = data.template_file.azure-storage-clusterrole.rendered
  filename = "${local.installer_workspace}/openshift/99_azure-storage-clusterrole.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "azure-file-storageclass" {
  template = <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
provisioner: kubernetes.io/azure-file
parameters:
  storageAccount: ${var.azure_storage_azurefile_name}
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
}

resource "local_file" "azure-file-storageclass" {
  content  = data.template_file.azure-file-storageclass.rendered
  filename = "${local.installer_workspace}/openshift/99_azure-file-storageclass.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}

data "template_file" "image-registry-pvc" {
  template = <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: image-registry-storage
  namespace: openshift-image-registry
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azure-file
EOF
}

resource "local_file" "image-registry-pvc" {
  content  = data.template_file.image-registry-pvc.rendered
  filename = "${local.installer_workspace}/openshift/99_image-registry-pvc.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}


data "template_file" "cluster-monitoring-configmap" {
  template = <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |+
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
EOF
}

resource "local_file" "cluster-monitoring-configmap" {
  content  = data.template_file.cluster-monitoring-configmap.rendered
  filename = "${local.installer_workspace}/openshift/99_cluster-monitoring-configmap.yml"
  depends_on = [
    "null_resource.dependency",
    "null_resource.download_binaries",
    "null_resource.generate_manifests",
  ]
}
