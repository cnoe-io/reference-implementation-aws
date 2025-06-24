# Kubeflow Spark Operator

[![Go Report Card](https://goreportcard.com/badge/github.com/kubeflow/spark-operator)](https://goreportcard.com/report/github.com/kubeflow/spark-operator)

## What is Spark Operator?

The Kubernetes Operator for Apache Spark aims to make specifying and running [Spark](https://github.com/apache/spark) applications as easy and idiomatic as running other workloads on Kubernetes. It uses
[Kubernetes custom resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) for specifying, running, and surfacing status of Spark applications.

## Overview

For a complete reference of the custom resource definitions, please refer to the [API Definition](docs/api-docs.md). For details on its design, please refer to the [Architecture](https://www.kubeflow.org/docs/components/spark-operator/overview/#architecture). It requires Spark 2.3 and above that supports Kubernetes as a native scheduler backend.

The Kubernetes Operator for Apache Spark currently supports the following list of features:

* Supports Spark 2.3 and up.
* Enables declarative application specification and management of applications through custom resources.
* Automatically runs `spark-submit` on behalf of users for each `SparkApplication` eligible for submission.
* Provides native [cron](https://en.wikipedia.org/wiki/Cron) support for running scheduled applications.
* Supports customization of Spark pods beyond what Spark natively is able to do through the mutating admission webhook, e.g., mounting ConfigMaps and volumes, and setting pod affinity/anti-affinity.
* Supports automatic application re-submission for updated `SparkApplication` objects with updated specification.
* Supports automatic application restart with a configurable restart policy.
* Supports automatic retries of failed submissions with optional linear back-off.
* Supports mounting local Hadoop configuration as a Kubernetes ConfigMap automatically via `sparkctl`.
* Supports automatically staging local application dependencies to Google Cloud Storage (GCS) via `sparkctl`.
* Supports collecting and exporting application-level metrics and driver/executor metrics to Prometheus.

## Project Status

**Project status:** *beta*

**Current API version:** *`v1beta2`*

**If you are currently using the `v1beta1` version of the APIs in your manifests, please update them to use the `v1beta2` version by changing `apiVersion: "sparkoperator.k8s.io/<version>"` to `apiVersion: "sparkoperator.k8s.io/v1beta2"`. You will also need to delete the `previous` version of the CustomResourceDefinitions named `sparkapplications.sparkoperator.k8s.io` and `scheduledsparkapplications.sparkoperator.k8s.io`, and replace them with the `v1beta2` version either by installing the latest version of the operator or by running `kubectl create -f config/crd/bases`.**

## Prerequisites

* Version >= 1.13 of Kubernetes to use the [`subresource` support for CustomResourceDefinitions](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/#subresources), which became beta in 1.13 and is enabled by default in 1.13 and higher.

* Version >= 1.16 of Kubernetes to use the `MutatingWebhook` and `ValidatingWebhook` of `apiVersion: admissionregistration.k8s.io/v1`.

## Getting Started

For getting started with Spark operator, please refer to [Getting Started](https://www.kubeflow.org/docs/components/spark-operator/getting-started/).

## User Guide

For detailed user guide and API documentation, please refer to [User Guide](https://www.kubeflow.org/docs/components/spark-operator/user-guide/) and [API Specification](docs/api-docs.md).

If you are running Spark operator on Google Kubernetes Engine (GKE) and want to use Google Cloud Storage (GCS) and/or BigQuery for reading/writing data, also refer to the [GCP guide](https://www.kubeflow.org/docs/components/spark-operator/user-guide/gcp/).

## Version Matrix

The following table lists the most recent few versions of the operator.

| Operator Version | API Version | Kubernetes Version | Base Spark Version |
| ------------- | ------------- | ------------- | ------------- |
| `v1beta2-1.6.x-3.5.0` | `v1beta2` | 1.16+ | `3.5.0` |
| `v1beta2-1.5.x-3.5.0` | `v1beta2` | 1.16+ | `3.5.0` |
| `v1beta2-1.4.x-3.5.0` | `v1beta2` | 1.16+ | `3.5.0` |
| `v1beta2-1.3.x-3.1.1` | `v1beta2` | 1.16+ | `3.1.1` |
| `v1beta2-1.2.3-3.1.1` | `v1beta2` | 1.13+ | `3.1.1` |
| `v1beta2-1.2.2-3.0.0` | `v1beta2` | 1.13+ | `3.0.0` |
| `v1beta2-1.2.1-3.0.0` | `v1beta2` | 1.13+ | `3.0.0` |
| `v1beta2-1.2.0-3.0.0` | `v1beta2` | 1.13+ | `3.0.0` |
| `v1beta2-1.1.x-2.4.5` | `v1beta2` | 1.13+ | `2.4.5` |
| `v1beta2-1.0.x-2.4.4` | `v1beta2` | 1.13+ | `2.4.4` |

## Developer Guide

For developing with Spark Operator, please refer to [Developer Guide](https://www.kubeflow.org/docs/components/spark-operator/developer-guide/).

## Contributor Guide

For contributing to Spark Operator, please refer to [Contributor Guide](CONTRIBUTING.md).

## Community

* Join the [CNCF Slack Channel](https://www.kubeflow.org/docs/about/community/#kubeflow-slack-channels) and then join `#kubeflow-spark-operator` Channel.
* Check out our blog post [Announcing the Kubeflow Spark Operator: Building a Stronger Spark on Kubernetes Community](https://blog.kubeflow.org/operators/2024/04/15/kubeflow-spark-operator.html).
* Join our monthly community meeting [Kubeflow Spark Operator Meeting Notes](https://bit.ly/3VGzP4n).

## Adopters

Check out [adopters of Spark Operator](ADOPTERS.md).

