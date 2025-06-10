# Backstage Helm Chart

This Helm chart deploys Backstage and its dependencies to a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (for PostgreSQL persistence)

## Installing the Chart

To install the chart with the release name `backstage`:

```bash
helm install backstage ./packages/backstage
```

## Configuration

The following table lists the configurable parameters of the Backstage chart and their default values.

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `namespace` | Namespace to deploy resources | `backstage` |
| `backstage.image.repository` | Backstage image repository | `public.ecr.aws/cnoe-io/backstage` |
| `backstage.image.tag` | Backstage image tag | `v0.0.2` |
| `backstage.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `backstage.replicas` | Number of Backstage replicas | `1` |
| `backstage.resources` | CPU/Memory resource requests/limits | See `values.yaml` |
| `backstage.serviceAccount.create` | Create service account | `true` |
| `backstage.serviceAccount.name` | Service account name | `backstage` |
| `backstage.config` | Backstage application configuration | See `values.yaml` |
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `postgresql.image.repository` | PostgreSQL image repository | `docker.io/library/postgres` |
| `postgresql.image.tag` | PostgreSQL image tag | `15.3-alpine3.18` |
| `postgresql.resources` | PostgreSQL resource requests/limits | See `values.yaml` |
| `postgresql.persistence.enabled` | Enable PostgreSQL persistence | `true` |
| `postgresql.persistence.storageClass` | PostgreSQL storage class | `gp2` |
| `postgresql.persistence.size` | PostgreSQL storage size | `1Gi` |
| `postgresql.env` | PostgreSQL environment variables | See `values.yaml` |
| `rbac.create` | Create RBAC resources | `true` |
| `rbac.rules` | RBAC rules | See `values.yaml` |
| `rbac.argoWorkflows.create` | Create Argo Workflows RBAC | `true` |
| `rbac.argoWorkflows.rules` | Argo Workflows RBAC rules | See `values.yaml` |
| `userRbac.enabled` | Enable user RBAC | `true` |
| `userRbac.superuserGroup` | Superuser group name | `superuser` |
| `userRbac.backstageUsersGroup` | Backstage users group name | `backstage-users` |
| `env` | Environment variables for Backstage | See `values.yaml` |

## Customizing the Chart

To customize the chart, create a `values.yaml` file with your changes and use it when installing:

```bash
helm install backstage ./packages/backstage -f my-values.yaml
```

## Uninstalling the Chart

To uninstall/delete the `backstage` deployment:

```bash
helm delete backstage
```