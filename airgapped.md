# Configuration for an AirGapped environment in Azure

This repository allows for a completely private, AirGapped implementation.  To configure it, a couple of pre-reqs first need to be met:

1. Create an image registry.  You can either create an image repository from scratch, or configure one using Azure's Container Registry.  The CoreOS VMs must be able to reach this repository.

## Creating an internal image regisry

  Creating an image registry using RedHat's [documentation](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html).
  Follow all steps up to Step 4 of [Mirroring the OpenShift Container Platform image repository](https://docs.openshift.com/container-platform/4.2/installing/installing_restricted_networks/installing-restricted-networks-preparations.html#installation-mirror-repository_installing-restricted-networks-preparations)


```bash
$ export OCP_RELEASE="4.2.0"
$ export LOCAL_REGISTRY="openshiftrepo.example.com:443"
$ export LOCAL_REPOSITORY="ocp4/openshift4"
$ export PRODUCT_REPO='openshift-release-dev' 
$ export LOCAL_SECRET_JSON='<path_to_pull_secret>' 
$ export RELEASE_NAME="ocp-release" 

$ oc adm -a ${LOCAL_SECRET_JSON} release mirror \
     --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE} \
     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}

 ...

sha256:211ece2d9718f7ab5c2a78d0124332626dafd18fc9f6562e7561ad182e82d816 openshiftrepo.example.com:443/ocp4/openshift4:kube-proxy
info: Mirroring completed in 18.64s (0B/s)

Success
Update image:  openshiftrepo.example.com:443/ocp4/openshift4:4.2.0
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


# Exposing the image registry to Terraform

In your terraform.tvfars, add the following at the bottom
```terraform
azure_private = true
airgapped     = {
  enabled     = true
  repository  = "openshiftibm.azurecr.io/ocp4/openshift4"
}
```

This ensures that terraform generates the `installer-config.yaml` and `ImageContentSourcePolicy` templates for a private, disconnected installation.
