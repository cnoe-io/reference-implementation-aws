
## Installation Flow Diagram
This diagram illustrates the high-level installation flow for the CNOE AWS Reference Implementation using **`idpbuilder`**. It shows how the **`idpbuilder`** and local environment interact with AWS resources to deploy and configure the platform on an EKS cluster.

```mermaid
flowchart TD
    subgraph "Local Environment"
        config["config.yaml"]
        secrets["GitHub App Credentials
        (private/*.yaml)"]
        create_secrets["create-config-secrets.sh"]
        install["install-using-idpbuilder.sh"]
        idpbuilder["idpbuilder
        (Local Kind Cluster)"]
        local_argocd["Argo CD
        (Kind Cluster)"]
        local_gitea["Gitea
        (Kind Cluster)"]
    end

    subgraph "AWS"
        aws_secrets["AWS Secrets Manager
        - cnoe-ref-impl/config
        - cnoe-ref-impl/github-app"]

        subgraph "EKS Cluster"
            eks_argocd["Argo CD"]
            eso["External Secret Operator"]
            appset["addons-appset
            (ApplicationSet)"]

            subgraph "Addons"
                backstage["Backstage"]
                keycloak["Keycloak"]
                crossplane["Crossplane"]
                cert_manager["Cert Manager"]
                external_dns["External DNS"]
                ingress["Ingress NGINX"]
                argo_workflows["Argo Workflows"]
            end
        end
    end

    config --> create_secrets
    secrets --> create_secrets
    create_secrets --> aws_secrets

    config --> install
    install --> idpbuilder

    idpbuilder --> local_argocd
    idpbuilder --> local_gitea

    local_argocd -- "Installs" --> eks_argocd
    local_argocd -- "Installs" --> eso
    local_argocd -- "Creates" --> appset

    aws_secrets -- "Provides configuration" --> eso

    appset -- "Creates Argo CD Addon ApplicationSets" --> Addons

    eks_argocd -- "Manages" --> Addons
    eso -- "Provides secrets to" --> Addons

    classDef aws fill:#FF9900,stroke:#232F3E,color:white;
    classDef k8s fill:#326CE5,stroke:#254AA5,color:white;
    classDef tools fill:#4CAF50,stroke:#388E3C,color:white;
    classDef config fill:#9C27B0,stroke:#7B1FA2,color:white;

    class aws_secrets,EKS aws;
    class eks_argocd,eso,appset,backstage,keycloak,crossplane,cert_manager,external_dns,ingress,argo_workflows k8s;
    class idpbuilder,local_argocd,local_gitea,install,create_secrets tools;
    class config,secrets config;
```

## Getting Started

> [!NOTE]
> The installation requires AWS credentials to access the EKS cluster to deploy kubernetes resources. Therefore, the installation steps can be executed on local machine or on an EC2 instance with IAM instance role. If using local machine, please use [`aws-vault`](https://github.com/99designs/aws-vault) command to run local EC2 credentials server. Find more information about this requirement in [installation flow](docs/installation_flow.md) document.

### Step 1. ☸️ Create EKS Cluster

The reference implementation can be installed on new EKS cluster which can be created with following tools:

+ **eksctl**: Follow the [instructions](cluster/eksctl)
+ **terraform**: Follow the [instructions](cluster/terraform/)

This will create all the pre-requisite AWS Resources required for the reference implementation. Which includes:

+ EKS cluster with Auto Mode or Without Auto Mode (Managed Node Group with 4 nodes)
+ Pod Identity Associations for following Addons:

| Name | Namespace | Service Account Name | Permissions |
| ----- | --------- | -------------------- | ---------- |
| Crossplane | crossplane-system | provider-aws | Admin Permissions but with [permission boundary](cluster/iam-policies/crossplane-permissions-boundry.json) |
| External Secrets | external-secrets | external-secrets | [Permissions](https://external-secrets.io/latest/provider/aws-secrets-manager/#iam-policy) |
| External DNS | external-dns | external-dns | [Permissions](https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/aws/#iam-policy) |
| AWS Load Balancer Controller<br>(When not using Auto Mode) | kube-system | aws-load-balancer-controller | [Permissions](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/main/docs/install/iam_policy.json) |
| AWS EBS CSI Controller<br>(When not using Auto Mode) | kube-system | ebs-csi-controller-sa | [Permissions](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicy.html) |


> [!NOTE]
> **Using Existing EKS Cluster**
>
> The reference implementation can be installed on existing EKS Cluster only if above pre-requisites are completed.

### Step 2. 🏢 Create GitHub Organization

Backstage and Argo CD in this reference implementation are integrated with GitHub. Therefore, a GitHub Organization should be created in order to create GitHub Apps for these integrations. Follow the instructions in [GitHub documentation](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/creating-a-new-organization-from-scratch) to create new organization.

### Step 3. 🍴 Fork the Repository

Once the organization is created, fork this repository to the new GitHub Organization by following instructions in [GitHub documentation](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo).

### Step 4. 💻 Create GitHub Apps

There are two ways to create GitHub App. You can use the Backstage CLI `npx @backstage/cli create-github-app <github-org>` as per instructions in [Backstage documentation](https://backstage.io/docs/integrations/github/github-apps/#using-the-cli-public-github-only), or create it manually per these instructions in [GitHub documentation](https://backstage.io/docs/integrations/github/github-apps).

Create following apps and store it in corresponding file path.

| App Name | Purpose | Required Permissions | File Path | Expected Content |
| -------- | ------- | -------------------- | --------- | ---------------- |
| Backstage | Used for automatically importing Backstage configuration such as Organization information, templates and creating new repositories for developer applications. | For All Repositories<br>- Read access to members, metadata, and organization administration<br>- Read and write access to administration and code | **`private/backstage-github.yaml`** | ![backstage-github-app](docs/images/backstage-github-app.png) |
| Argo CD | Used for deploying resources to cluster specified by Argo CD applications.| For All Repositories<br>- Read access to checks, code, members, and metadata| **`private/argocd-github.yaml`** | ![argocd-github-app](docs/images/argocd-github-app.png) |

Argo CD requires `url` and `installationId` of the GitHub app. The `url` is the GitHub URL of the organization. The `installationId` can be captured by navigating to the app installation page with URL `https://github.com/organizations/<Organization-name>/settings/installations/<ID>`. You can find more information [on this page](https://stackoverflow.com/questions/74462420/where-can-we-find-github-apps-installation-id).

> [!WARNING]
> **If the app is created using backstage CLI, it creates files in current working directory. These files contains credentials. Handle it with care. It is recommended to remove these files after copying the content over to files in `private` directory**

> [!NOTE]
> The rest of the installation process assumes the GitHub apps credentials are available in `private/backstage-github.yaml` and `private/argocd-github.yaml`

### Step 5. ⚙️ Prepare Environment for Installation

#### 📦 Install Binaries

The installation requires following binaries in the local environment:

+ [**AWS CLI**](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
+ [**Docker**](https://docs.docker.com/engine/install/)
+ [**yq**](https://mikefarah.gitbook.io/yq/v3.x)
+ [**helm**](https://helm.sh/docs/intro/install/) _(Required only if using plain shell script for installation)_
+ [**IDPBuilder**](https://github.com/cnoe-io/idpbuilder) _(Required only if using ipdbuilder for installation)_
+ [**AWS Vault**](https://github.com/99designs/aws-vault?tab=readme-ov-file#installing) _(Required only for local machine installation)_

#### 🔐 Configure AWS Credentials

If the installation steps are being executed on EC2 instance, just ensure that the EC2 IAM instance role has permissions to access EKS cluster. No other configuration is required in this case.

If the steps are being executed on a laptop/desktop, follow below steps:

1. Configure the AWS CLI with credentials of an IAM role which has access to the EKS cluster. Follow instructions in [AWS documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html#getting-started-quickstart-new) to configure AWS CLI.
2. Once AWS CLI is configured, install and start the EC2 credentials server.

   ```bash
   aws-vault exec <AWS_PROFILE> --ec2-server
   ```

3. Verify that the EC2 credentials server is started.

   ```bash
   curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/local-credentials
   ```

#### ⚙️ Configure Reference Implementation

The reference implementation uses **`config.yaml`** file in the repository root directory to pass values. Refer to following table and update all the values appropriately. All the values are required.

| Parameter | Description | Type |
|-----------|-------------|------|
| `repo.url` | GitHub URL of the fork in Github Org | string |
| `repo.revision` | Branch or Tag which should be used for Argo CD Apps | string |
| `repo.basepath` | Directory in which configuration of addons is stored | string |
| `cluster_name` | Name of the EKS cluster for reference implementation <br> **(The name should satisfy criteria of a valid [kubernetes resource name](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/))** | string |
| `auto_mode` | Set to "true" if EKS cluster is Auto Mode, otherwise "false" | string |
| `region` | AWS Region of the EKS cluster and config secret | string |
| `domain` | Base Domain name for exposing services<br>**(This should be base domain or sub domain of the Route53 Hosted Zone)** | string |
| `route53_hosted_zone_id` | Route53 hosted zone ID for configuring external-dns | string |
| `path_routing` | Enable path routing ("true") vs domain-based routing ("false") | string |
| `tags` | Arbitrary key-value pairs for AWS resource tagging | object |

#### 🔒 Create Secrets in AWS Secret Manager

The values required for the installation to work are stored in AWS Secret Manager in two secrets:

1. **cnoe-ref-impl/config:** Stores values from **`config.yaml`** in JSON
2. **cnoe-ref-impl/github-app:** Stores GitHub App credentials with file name as key and content of the file as value from **private** directory.

Run below command to create new secrets or update the existing secrets if already exists.

```bash
./scripts/create-config-secrets.sh
```

> [!WARNING]
> **DO NOT** move to next steps without completing all the instructions in this step

### Step 6. 🚀 Installation

#### ▶️ Start the Installation Process

The installation can be done using plain shell script or `idpbuilder`. All the addons are installed as Argo CD apps. When using bash script, Argo CD and External Secret Operator are installed on EKS cluster as helm chart. When installing with `idpbuilder`, the Argo CD in `idpbuilder` is used install these initial addons. Once Argo CD on EKS is up, other addons are installed through it and finally the Argo CD on EKS also manages itself. Check out more details about the [installation flow](docs/installation_flow.md).

+ **Install using script:**
   ```bash
   ./scripts/install.sh
   ```

+ **Install using `idpbuilder`:**
   ```bash
   ./scripts/install-using-idpbuilder.sh
   ```

#### 📊 Monitor Installation Process

The installation script will continue to run until all the addon Argo CD apps are healthy. To monitor the process, use below instructions to access Argo CD instances. _(If using EC2 instance, make sure the port-forward from EC2 to local machine is set up)_

+ **`idpbuilder` Argo CD:** `idpbuilder` exposes its Argo CD instance at `https://cnoe.localtest.me:8443/argocd` which can be accessed through browser.

+ **EKS Argo CD:** Start the kubernetes port-forward session for Argo CD service and access the Argo CD UI in browser. In Argo CD UI, monitor the health of all Argo CD Apps

  ```bash
  kubectl port-forward -n argocd svc/argocd-server 8080:80
  ```

Depending upon the configuration, Argo CD will be accessible at http://localhost:8080 or http://localhost:8080/argocd.

Switch between the kubernetes context of idpbuilder or EKS and retrieve the credentials for Argo CD can be retrieved with following command:

```bash
kubectl get secrets -n argocd argocd-initial-admin-secret -oyaml | yq '.data.password' | base64 -d

# OR

idpbuilder get secrets -p argocd -o yaml
```

### Step 7. 🌐 Accessing the Platform

The addons are exposed using the base domain configured in [Step 5](#️-configure-reference-implementation). The URL depends on the setting for `path_routing`. Refer to following table for URLs:

| App Name | URL (w/ Path Routing) | URL (w/o Path Routing) |
| --------- | --------- | --------- |
| Backstage | https://[domain] | https://backstage.[domain] |
| Argo CD | https://[domain]/argocd | https://argocd.[domain] |
| Argo Workflows | https://[domain]/argo-workflows | https://argo-workflows.[domain] |

All the addons are configured with Keycloak SSO USER1 and the user password for it can be retrieved using following command:

```bash
kubectl get secrets -n keycloak keycloak-config -o go-template='{{range $k,$v := .data}}{{printf "%s: " $k}}{{if not $v}}{{$v}}{{else}}{{$v | base64decode}}{{end}}{{"\n"}}{{end}}'
```
Once, all the Argo CD apps on EKS cluster are reporting healthy status, try out [examples](docs/examples/) to create new application through Backstage.
For troubleshooting, refer to the [troubleshooting guide](docs/troubleshooting.md).

## Cleanup
> [!WARNING]
> Before proceeding with the cleanup, ensure any Kubernetes resource created outside of the installation process such as Argo CD Apps, deployments, volume etc. are deleted.

Run following command to remove all the addons created by this installation:

```
./scripts/uninstall.sh
```

This script will only remove resources other than CRDs from the EKS cluster so that the same cluster can used for re-installation which is useful during development. To remove CRDs, use following command:

```
./scripts/cleanup-crds.sh
```

# Installation Flow

This document describes the installation flow for the CNOE AWS Reference Implementation.

## Overview

The CNOE AWS Reference Implementation uses a GitOps approach to deploy and manage addons on an EKS cluster. The installation process uses `helm` to bootstrap the EKS cluster with Argo CD and other addons. Detailed installation sequence is described below.

## Installation Sequence

1. **Configuration Setup**:
   - The `config.yaml` file is used to configure the installation
   - AWS Secrets Manager secrets are created to store configuration and GitHub App credentials using `create-config-secrets.sh` script

2. **Local Environment Preparation**:
   + Using plain shell script:
      - `install.sh` script reads the `config.yaml` and based on the specified cluster name, performs helm installation on EKS cluster.
   + Using idpbuilder:
      - `install-using-idpbuilder.sh` script reads the `config.yaml` and based on the specified cluster name, builds a Argo CD cluster secret from eks kubeconfig.
      - `idpbuilder` creates a local Kind cluster with Argo CD, Gitea and Argo CD cluster secret for EKS cluster.
      - This local environment serves as a bootstrap mechanism for the remote EKS cluster using Argo CD in Kind cluster.

3. **EKS Cluster Bootstrap**:
   + Using plain shell script:
      - The script performs helm installation of Argo CD and External Secret Operator on the EKS cluster. It will use the temporary kubeconfig for accessing EKS cluster.
   + Using idpbuilder:
      - `idpbuilder` applies Argo CD applications from the root of `packages` directory to the local Kind cluster, mainly `boostrap.yaml` and `addons-appset.yaml`.
      - Argo CD in the Kind cluster installs Argo CD and External Secret Operator on the EKS cluster. It will use AWS credentials to authenticate with EKS cluster.

4. **Addons Deployment**:
   - The `addons-appset.yaml` creates an ApplicationSet in the EKS cluster's Argo CD
   - This ApplicationSet creates individual Argo CD applicationSet for each addon using [cluster generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/).
   - Addons are installed in a specific order to handle dependencies

5. **Addon Configuration**:
   - Addons are configured using helm values
   - Static values are stored `packages/<addon-name>/values.yaml`
   - Dynamic values from Argo CD cluster secret labels/annotations which depend on configuration from AWS Secrets Manager. 

6. **Monitoring and Verification**:
   - The installation script waits for all Argo CD applications to become healthy
   - Addons can be accessed through the configured domain based on path routing settings

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

## Key Components

1. **helm** _(if using `install.sh`)_: Bootstraps EKS cluster through helm chart installation.
2. **idpbuilder** _(if using `install-using-idpbuilder.sh`)_: Creates a local Kind cluster with Argo CD and Gitea, which bootstraps the EKS cluster
3. **Argo CD**: Manages the deployment of addons on the EKS cluster using GitOps
4. **External Secret Operator**: Manages secrets from AWS Secrets Manager
5. **Addons**: Various tools and services that make up the Internal Developer Platform

## AWS Resources

The installation relies on these AWS resources:

1. **EKS Cluster**: The Kubernetes cluster where the platform is deployed
2. **AWS Secrets Manager**: Stores configuration and GitHub App credentials
3. **IAM Roles**: For pod identity associations required by various addons
4. **Route53**: For DNS management via External DNS
