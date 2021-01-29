# Configuration for an AirGapped environment in Azure

This repository allows for a completely private, AirGapped implementation.  To configure it, a couple of pre-reqs first need to be met:

1. Create an image registry.  You can either create an image repository from scratch, or configure one using Azure's Container Registry.  The CoreOS VMs must be able to reach this repository.

## Creating an internal image regisry

  Creating an image registry using RedHat's [documentation](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html).
  Follow all steps up to Step 4 of [Mirroring the OpenShift Container Platform image repository](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html#installation-mirror-repository_installing-restricted-networks-preparations)


```bash
$ export OCP_RELEASE="4.3.26-x86_64"
$ export LOCAL_REGISTRY="openshiftrepo.example.com:443"
$ export LOCAL_REPOSITORY="ocp4/openshift4"
$ export PRODUCT_REPO='openshift-release-dev' 
$ export LOCAL_SECRET_JSON='<path_to_pull_secret>' 
$ export RELEASE_NAME="ocp-release" 

$ oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}
info: Mirroring 103 images to openshiftrepo.example.com:443/ocp4/openshift4 ...
openshiftrepo.example.com:443/
  ocp4/openshift4
    blobs:
...

sha256:1a69a2bf32e9c39c4395de6c7fbcfbe8f430eb23476a8b85036e67e60050ce53 openshiftrepo.example.com:443/ocp4/openshift4:4.3.26-cluster-authentication-operator
info: Mirroring completed in 1m27.76s (8.084MB/s)

Success
Update image:  openshiftrepo.example.com:443/ocp4/openshift4:4.3.26-x86_64
Mirror prefix: openshiftrepo.example.com:443/ocp4/openshift4

To use the new mirrored repository to install, add the following section to the install-config.yaml:

imageContentSources:
- mirrors:
  - openshiftrepo.example.com:443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - openshiftrepo.example.com:443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev


To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - openshiftrepo.example.com:443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - openshiftrepo.example.com:443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

## Creating an [Azure Container Registry](https://azure.microsoft.com/en-us/services/container-registry/) Instance

On a separate resource group, [create an instance](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal) of the Azure Container Registry (ACR) service.  You can use the same resource group where the public DNZ Zone is hosted. When selecting the ACR SKU, select Premium if you wish to restrict network access to specific networks inside your subscription.  Otherwise select Standard which provides 100GB of storage.  Basic only provides 10GB of storage and should not be used.  Enable Admin User to quickly get an username and password that can be used to generate the OpenShift Pull Secret for this repository.  You can find these values in the `Access Keys` configuration of the ACR.

Once the registry is created, follow the RedHat Documentation from [Creating a pull secret for your mirror registry](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html#installation-local-registry-pull-secret_installing-restricted-networks-preparations) up to Step 4 of [Mirroring the OpenShift Container Platform image repository](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html#installation-mirror-repository_installing-restricted-networks-preparations)


# Airgapped Scenarios

## Private Endpoints with Egress Provided by Azure Public LB
When `azure_private` is set to true, the `api` and `*.apps` domains are configured on Private LoadBalancers.  A public loadbalancer is created to provide egress access to the cluster, but no inbound access is allowed.  If you want to use a mirrored registry, you can also include the `airgapped` variable in your terraform.tfvars file

```terraform
azure_private = true
airgapped     = {
  enabled     = true
  repository  = "example.azurecr.io/ocp4/openshift4"
}
```

## Private Endpoints with User Defined Routing
In addition to `azure_private` and `airgapped` variables, you can set other variables that ensure all communication to your cluster are handled via internal endpoints and no traffic goes thru the Azure public network.  You are responsible for configuring addecuate access to the internet in your VNET (via a ExpressRoute, Proxies, etc).  Set the `azure_outbound_user_defined_routing` and `azure_preexisting_network` variabes to `true` and provide your VNET Resource Group, VNET Name and Control Plane and Compute Subnets

```terraform
azure_private = true
airgapped     = {
  enabled     = true
  repository  = "example.azurecr.io/ocp4/openshift4"
}
azure_outbound_user_defined_routing = true
azure_preexisting_network = true
azure_network_resource_group_name = "yourNetworkResourceGroup"
azure_virtual_network = "yourVNETName"
azure_control_plane_subnet = "yourControlPlaneSubnetName"
azure_compute_subnet = "yourComputeSubnetName"
```

This ensures that terraform generates the `installer-config.yaml` and `ImageContentSourcePolicy` templates for a private, disconnected installation.

## Proxied Environments
When `proxy_config` is set, the cluster wide proxy will be configured during install for your OCP cluster.  You can specify your http and https proxies, any addresses that are not to be proxied, as well as the certificate trust bundle for your proxy.  When `proxy_config.enabled` is set to true, your install-config.yaml will be auto-generated with the proper proxy configuration

```terraform
proxy_config = {
  enabled               = true                                         # set to true to enable proxy configuration
  httpProxy             = "http://user:password@proxy.example.com:80"  # only supports http proxies at this time
  httpsProxy            = "http://user:password@proxy.example.com:80"  # only supports http proxies at this time
  noProxy               = "ip1,ip2,ip3,.example.com,10.0.0.0/8"        # comma delimited values
  additionalTrustBundle = "/path/to/trust/bundle.pem"                  # set to "" for no additionalTrustBundle
}
```
