# Application Sets Helm Chart

This Helm chart deploys ApplicationSets for managing various addons in a Kubernetes cluster using Argo CD.

## Overview

The Application Sets chart is designed to deploy and manage multiple Kubernetes addons across clusters using Argo CD's ApplicationSet controller. It provides a standardized way to deploy common addons such as:

- Argo CD
- AWS Load Balancer Controller
- Ingress NGINX
- External DNS
- External Secrets
- Cert Manager
- Keycloak
- Backstage

## Prerequisites

- Kubernetes cluster
- Argo CD installed
- Helm 3.x

## Installation

```bash
helm install application-sets ./chart -n argocd
```

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `syncPolicy` | Default sync policy for all applications | See values.yaml |
| `syncPolicyAppSet` | Sync policy for ApplicationSets | `{ preserveResourcesOnDeletion: true }` |
| `useSelectors` | Whether to use selectors for targeting clusters | `true` |
| `repoURLGit` | Git repository URL for addons | `'{{.metadata.annotations.addons_repo_url}}'` |
| `repoURLGitRevision` | Git repository revision for addons | `'{{.metadata.annotations.addons_repo_revision}}'` |
| `repoURLGitBasePath` | Base path in Git repository for addons | `'{{.metadata.annotations.addons_repo_basepath}}'` |
| `useValuesFilePrefix` | Whether to use a prefix for values files | `false` |
| `valuesFilePrefix` | Prefix for values files | `''` |
| `appsetPrefix` | Prefix for ApplicationSet names | `''` |

### Addon Configuration

Each addon is configured as a top-level key in the values file. The following parameters are available for each addon:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `enabled` | Whether to enable the addon | `false` |
| `namespace` | Namespace to deploy the addon | Varies by addon |
| `chartName` | Name of the Helm chart | Same as addon key |
| `releaseName` | Name of the Helm release | Same as addon key |
| `defaultVersion` | Default version of the chart | Varies by addon |
| `chartRepository` | Repository URL for the chart | Varies by addon |
| `chartNamespace` | Namespace in the chart repository | `''` |
| `enableAckPodIdentity` | Whether to enable AWS Controller for Kubernetes Pod Identity | `false` |
| `selector` | Selector for targeting clusters | `{}` |
| `selectorMatchLabels` | Match labels for targeting clusters | `{}` |
| `valuesObject` | Values to pass to the Helm chart | `{}` |
| `ignoreDifferences` | Resources to ignore differences for | `[]` |
| `additionalResources` | Additional resources to deploy | `{}` |
| `syncPolicy` | Sync policy for the addon | Same as global `syncPolicy` |
| `annotationsAppSet` | Annotations for the ApplicationSet | `{}` |
| `annotationsApp` | Annotations for the Application | `{}` |
| `labelsAppSet` | Labels for the ApplicationSet | `{}` |
| `environments` | Environment-specific configurations | `[]` |

## Values File Structure

```yaml
# Global configuration
syncPolicy:
  automated:
    selfHeal: false
    allowEmpty: true
    prune: false
  retry:
    limit: -1
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 10m
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true

syncPolicyAppSet:
  preserveResourcesOnDeletion: true

useSelectors: true
repoURLGit: '{{.metadata.annotations.addons_repo_url}}'
repoURLGitRevision: '{{.metadata.annotations.addons_repo_revision}}'
repoURLGitBasePath: '{{.metadata.annotations.addons_repo_basepath}}'

# Addon configurations
argocd:
  enabled: true
  chartName: argo-cd
  namespace: argocd
  releaseName: argocd
  defaultVersion: "8.0.14"
  chartRepository: "https://argoproj.github.io/argo-helm"
  additionalResources:
    path: true
    manifestPath: "manifests"
    type: "manifests"

aws-load-balancer-controller:
  enabled: true
  namespace: kube-system
  defaultVersion: "1.13.2"
  chartRepository: "https://aws.github.io/eks-charts"
  valuesObject:
    serviceAccount:
      name: "aws-load-balancer-controller"
    clusterName: '{{.name}}'
  ignoreDifferences:
    - kind: Secret
      name: aws-load-balancer-tls
      jsonPointers: [/data]
    - group: admissionregistration.k8s.io
      kind: MutatingWebhookConfiguration
      jqPathExpressions: ['.webhooks[].clientConfig.caBundle']
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      jqPathExpressions: ['.webhooks[].clientConfig.caBundle']

# Additional addons follow the same pattern
```

## Advanced Features

### Pod Identity

For addons that require AWS IAM roles, you can enable Pod Identity:

```yaml
addon-name:
  enabled: true
  enableAckPodIdentity: true
  # other configuration
```

### Additional Resources

You can deploy additional resources alongside an addon:

```yaml
addon-name:
  enabled: true
  additionalResources:
    path: true
    manifestPath: "manifests"
    type: "manifests"
```

### Environment-Specific Configurations

You can specify different chart versions for different environments:

```yaml
addon-name:
  enabled: true
  environments:
    - selector:
        environment: staging
        tenant: tenant1
      chartVersion: "1.2.3"
```

## Templates

The chart includes several helper templates:

- `_helpers.tpl`: Common helper functions
- `_application_set.tpl`: ApplicationSet generation
- `_git_matrix.tpl`: Git matrix generator
- `_pod_identity.tpl`: Pod identity configuration

## License

This chart is licensed under the Apache License 2.0.