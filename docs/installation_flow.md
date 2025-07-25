# Installation Flow

This document describes the installation flow for the CNOE AWS Reference Implementation.

## Overview

The CNOE AWS Reference Implementation uses a GitOps approach to deploy and manage addons on an EKS cluster. The installation process uses `helm` to bootstrap the EKS cluster. Detailed installation sequence is described below.

## Installation Process

1. **User Approval**
   - User starts by executing the `scripts/install.sh` script which displays details such as target EKS cluster and AWS Region etc. It also requests approval from the user to proceed with installation.

2. **Setup Configuration**:
   - AWS Secrets Manager secrets are created to store configuration and GitHub App credentials using `create-config-secrets.sh` script. These secrets are fetched into the cluster by External Secret Operator.
   - The `config.yaml` file is used to configure the installation.
   - `install.sh` script reads the `config.yaml` and based on the specified cluster name, fetches kubeconfig of EKS cluster using AWS CLI. This kubeconfig is used for helm installation by overriding default kubeconfig.

3. **EKS Cluster Bootstrap**:
   - The script first performs helm installation of Argo CD and External Secret Operator (ESO) on the EKS cluster. It will use the temporary kubeconfig for accessing the EKS cluster. The values used for installation are static values from `packages/<addon-name>/values.yaml` which are the same files used by addons later.
   - Then the script applies custom manifests for these addons from the directory `packages/<addon-name>/manifests/`. For ESO, this directory contains the AWS Secret Manager ClusterStore manifest and for Argo CD, it contains manifests for External Secrets of in-cluster Argo CD secret and Github App Argo CD repository credentials. These External Secrets use AWS Secret Manager ClusterStore.
   - Then ESO will create corresponding kubernetes secrets for Argo CD cluster secret and repository credentials by fetching values from AWS Secret Manager which were created earlier.

4. **Addons Deployment**:
   - The script will wait 10 seconds and install the AppSet chart on the EKS cluster which creates ApplicationSets for all the enabled addons based on values in `packages/addons/values.yaml`. 
   - Each ApplicationSet will use [Argo CD Cluster Generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/) to create respective Argo CD Application. The Cluster Generator will generate one Argo CD Application for each enabled addon as there is only one Argo CD cluster secret.
   - Although the Argo CD Applications for each addon are created, each addon will take some time to reach Healthy state due to dependencies explained in the [dependency section](#addons-dependencies).

5. **Addon Configuration**:
   - Addons are configured using helm values
   - Static values are stored in `packages/<addon-name>/values.yaml`
   - Dynamic values from Argo CD cluster secret labels/annotations depend on configuration from AWS Secrets Manager. 

7. **Monitoring and Verification**:
   - The installation script waits for all Argo CD applications to become healthy
   - Addons can be accessed through the configured domain based on path routing settings

## Addons Dependencies
   The following is the order for addons reaching healthy state when using Path Routing.
   ```mermaid
      flowchart LR
         ESO["ESO"] --> ArgoCD["ArgoCD"]
         ArgoCD --> AWSLB["AWS Load Balancer Controller"] & ExternalDNS["External DNS"] & CertManager["Cert Manager"] & Crossplane["Crossplane"] & CrossplaneComp["Crossplane Compositions"] & Keycloak["Keycloak"]
         AWSLB --> NGINX["NGINX"]
         ExternalDNS --> Backstage["Backstage"] & ArgoWorkflows["Argo Workflows"]
         CertManager --> Backstage & ArgoWorkflows
         NGINX --> Backstage & ArgoWorkflows
         Keycloak --> Backstage & ArgoWorkflows

         linkStyle 0 stroke:#2962FF
         linkStyle 1 stroke:#00C853,fill:none
         linkStyle 2 stroke:#00C853,fill:none
         linkStyle 3 stroke:#00C853,fill:none
         linkStyle 4 stroke:#00C853,fill:none
         linkStyle 5 stroke:#00C853,fill:none
         linkStyle 6 stroke:#00C853,fill:none
         linkStyle 7 stroke:#E1BEE7,fill:none
         linkStyle 8 stroke:#FF6D00,fill:none
         linkStyle 9 stroke:#FFD600,fill:none
         linkStyle 10 stroke:#FF6D00,fill:none
         linkStyle 11 stroke:#FFD600,fill:none
         linkStyle 12 stroke:#FF6D00,fill:none
         linkStyle 13 stroke:#FFD600,fill:none
         linkStyle 14 stroke:#FF6D00,fill:none
         linkStyle 15 stroke:#FFD600,fill:none
   ```
   - The colors of edges in this diagram indicate the parallel progress of addons to reach healthy state. As seen in the diagram, all the addons will reach the Healthy state in parallel except Cert Manager, Keycloak, Backstage and Argo Workflows. 
   - Both Backstage and Argo Workflow addons depend on the Healthy status of External DNS, Cert-Manager, NGINX and Keycloak.
   - This sequential order for these addons is due to dependency of Keycloak Client creation for Backstage and Argo Workflows and both these addons also need to reach Keycloak using external URL to verify SSO configuration. Therefore, both Backstage and Argo Workflows will stay unhealthy until Keycloak reaches healthy state.
   - The Keycloak client creation is done using a Job pod _(`packages/keycloak/manifests/user-sso-config-job.yaml`)_. This job pod creates the Keycloak clients for Argo CD, Backstage and Argo Workflows. It also creates the kubernetes secret `keycloak-clients` containing client secrets. 
   - Once the client creation is successful, The ClusterSecretStore _(`packages/keycloak/manifests/keycloak-cluster-secret-store.yaml`)_ is created so that ESO can create kubernetes secrets for Client Secrets in Backstage and Argo Workflows namespace. 
   - When the kubernetes secrets for Keycloak Client Secrets are created in Backstage and Argo Workflows namespace, these addons will reach Healthy state.

## Uninstallation Process

The uninstallation process follows these steps:

1. **Remove idpbuilder Local Cluster**:
   - The local Kind cluster created by idpbuilder is deleted

2. **Remove Addons**:
   - Addons are removed in a specific order to handle dependencies
   - ApplicationSets are deleted with orphan deletion policy
   - PVCs for stateful applications are cleaned up

3. **CRD Cleanup (Optional)**:
   - Custom Resource Definitions can be cleaned up using the `cleanup-crds.sh` script
   - This is optional and useful when you want to completely remove all traces of the installation
