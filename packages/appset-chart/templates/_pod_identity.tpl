{{/*
Template to generate pod-identity configuration
*/}}
{{- define "application-sets.pod-identity" -}}
{{- $chartName := .chartName -}}
{{- $chartConfig := .chartConfig -}}
{{- $valueFiles := .valueFiles -}}
{{- $values := .values -}}
{{- with merge (default dict $values.ackPodIdentity) (default dict $chartConfig.ackPodIdentity) }}
{{- if .path }}
- repoURL: '{{ $values.repoURLGit }}'
  targetRevision: '{{ $values.repoURLGitRevision }}'
  path: {{default "charts/pod-identity" $values.ackPodIdentity.path }}
{{- else if .repoURL }}
- repoURL: '{{ $values.ackPodIdentity.repoURL }}'
  chart: '{{ $values.ackPodIdentity.chart }}'
  targetRevision: '{{ $values.ackPodIdentity.chartVersion }}'
{{- end }}
{{- end }}
  helm:
    releaseName: '{{`{{ .name }}`}}-{{ $chartConfig.chartName | default $chartName }}'
    valuesObject:
      create: '{{`{{default "`}}{{ $chartConfig.enableAckPodIdentity }}{{`" (index .metadata.annotations "ack_create")}}`}}'
      region: '{{`{{ .metadata.annotations.aws_region }}`}}'
      accountId: '{{`{{ .metadata.annotations.aws_account_id}}`}}'
      podIdentityAssociation:
        clusterName: '{{`{{ .name }}`}}'
        namespace: '{{ default $chartConfig.namespace .namespace }}'
    ignoreMissingValueFiles: true
    valueFiles:
     {{- include "application-sets.valueFiles" (dict 
     "nameNormalize" $chartName 
     "valueFiles" $valueFiles 
     "values" $values "chartType" "pod-identity") | nindent 6 }}
{{- end }}
