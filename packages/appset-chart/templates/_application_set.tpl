{{/*
Template to generate additional resources configuration
*/}}
{{- define "application-sets.additionalResources" -}}
{{- $chartName := .chartName -}}
{{- $chartConfig := .chartConfig -}}
{{- $valueFiles := .valueFiles -}}
{{- $values := .values -}}

{{- range $resource := $chartConfig.additionalResources }}
- repoURL: {{ $values.repoURLGit | squote }}
  targetRevision: {{ $values.repoURLGitRevision | squote }}
  path: {{- if eq $resource.type "manifests" }}
    '{{ $values.repoURLGitBasePath }}/{{ $chartName }}{{ if $values.useValuesFilePrefix }}{{ $values.valuesFilePrefix }}{{ end }}/{{ $resource.manifestPath }}'
  {{- else }}
    {{ $resource.path | squote }}
  {{- end}}
  {{- if $resource.helm }}
  helm:
    releaseName: '{{`{{ .name }}`}}-{{ $resource.helm.releaseName }}'
    {{- if $resource.helm.valuesObject }}
    valuesObject:
    {{- $resource.helm.valuesObject | toYaml | nindent 6 }}
    {{- end }}
    ignoreMissingValueFiles: true
    valueFiles:
    {{- include "application-sets.valueFiles" (dict
      "nameNormalize" $chartName
      "valueFiles" $valueFiles
      "values" $values
      "chartType" $resource.type) | nindent 6 }}
  {{- end }}
{{- end }}
{{- end }}


{{/*
Define the values path for reusability
*/}}
{{- define "application-sets.valueFiles" -}}
{{- $nameNormalize := .nameNormalize -}}
{{- $chartConfig := .chartConfig -}}
{{- $valueFiles := .valueFiles -}}
{{- $chartType := .chartType -}}
{{- $values := .values -}}
{{- with .valueFiles }}
{{- range . }}
- $values/{{ $values.repoURLGitBasePath }}/{{ $nameNormalize }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}{{ . }}{{ end }}
{{- if $values.useValuesFilePrefix }}
- $values/{{ $values.repoURLGitBasePath }}/{{ if $values.useValuesFilePrefix }}{{ $values.valuesFilePrefix }}{{ end }}{{ . }}/{{ $nameNormalize }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}values.yaml{{ end }}
{{- end }}
{{- end }}
{{- end }}
{{- with $chartConfig.valueFiles }}
{{- range . }}
- $values/{{ $values.repoURLGitBasePath }}/{{ $nameNormalize }}{{ if $chartType }}/{{ $chartType }}{{ end }}/{{ if $chartConfig.valuesFileName }}{{ $chartConfig.valuesFileName }}{{ else }}{{ . }}{{ end }}
{{- end }}
{{- end }}
{{- end }}
