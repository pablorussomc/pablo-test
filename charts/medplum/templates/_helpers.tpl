{{/*
Expand the name of the chart.
*/}}
{{- define "medplum.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Return the namespace to be used for the resources.
*/}}
{{- define "medplum.namespace" -}}
{{- default "medplum" .Values.namespace }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "medplum.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "medplum.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "medplum.labels" -}}
helm.sh/chart: {{ include "medplum.chart" . }}
{{ include "medplum.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "medplum.selectorLabels" -}}
app.kubernetes.io/name: {{ include "medplum.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "medplum.serviceAccountName" -}}
{{- if or (.Values.serviceAccount.create | default true) }}
{{- default (include "medplum.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Check if cloud provider is GCP
*/}}
{{- define "medplum.isGCP" -}}
{{- eq .Values.global.cloudProvider "gcp" -}}
{{- end }}

{{/*
Check if GCP ingress should be deployed
*/}}
{{- define "medplum.shouldDeployGCPIngress" -}}
{{- and (include "medplum.isGCP" .) .Values.ingress.deploy -}}
{{- end }}

{{/*
Validate GCP configuration when GCP is the cloud provider
*/}}
{{- define "medplum.validateGCPConfig" -}}
{{- if include "medplum.isGCP" . -}}
  {{- if not .Values.global.gcp.projectId -}}
    {{- fail "GCP project ID is required when using GCP cloud provider. Please set global.gcp.projectId" -}}
  {{- end -}}
  {{- if not .Values.global.gcp.secretId -}}
    {{- fail "GCP secret ID is required when using GCP cloud provider. Please set global.gcp.secretId" -}}
  {{- end -}}
  {{- if and .Values.ingress.deploy (not .Values.ingress.domain) -}}
    {{- fail "Domain is required when ingress is enabled. Please set ingress.domain" -}}
  {{- end -}}
{{- end -}}
{{- end }}

