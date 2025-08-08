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
    {{- fail "ERROR: GCP project ID is required when using GCP cloud provider.\nPlease set 'global.gcp.projectId' in your values.yaml file.\nExample: global.gcp.projectId: \"my-healthcare-project-123456\"" -}}
  {{- end -}}
  {{- if not .Values.global.gcp.secretId -}}
    {{- fail "ERROR: GCP secret ID is required when using GCP cloud provider.\nPlease set 'global.gcp.secretId' in your values.yaml file.\nExample: global.gcp.secretId: \"medplum-server-config\"" -}}
  {{- end -}}
  {{- if and .Values.ingress.deploy (not .Values.ingress.domain) -}}
    {{- fail "ERROR: Domain is required when ingress is enabled.\nPlease set 'ingress.domain' in your values.yaml file.\nExample: ingress.domain: \"medplum.example.com\"" -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate service account configuration for GCP Workload Identity
*/}}
{{- define "medplum.validateServiceAccount" -}}
{{- if include "medplum.isGCP" . -}}
  {{- if not .Values.serviceAccount.annotations -}}
    {{- fail "ERROR: Service account annotations are required for GCP Workload Identity.\nPlease set 'serviceAccount.annotations' in your values.yaml file.\nExample:\nserviceAccount:\n  annotations:\n    iam.gke.io/gcp-service-account: \"medplum-server@my-project-123456.iam.gserviceaccount.com\"" -}}
  {{- end -}}
  {{- $gcpServiceAccount := index .Values.serviceAccount.annotations "iam.gke.io/gcp-service-account" -}}
  {{- if not $gcpServiceAccount -}}
    {{- fail "ERROR: GCP service account annotation is required for Workload Identity.\nPlease set 'serviceAccount.annotations.iam.gke.io/gcp-service-account' in your values.yaml file.\nExample: iam.gke.io/gcp-service-account: \"medplum-server@my-project-123456.iam.gserviceaccount.com\"" -}}
  {{- end -}}
  {{- if not (contains "@" $gcpServiceAccount) -}}
    {{- fail "ERROR: Invalid GCP service account format.\nThe service account must be in the format: SERVICE_ACCOUNT_NAME@PROJECT_ID.iam.gserviceaccount.com\nCurrent value: " $gcpServiceAccount -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate resource configuration
*/}}
{{- define "medplum.validateResources" -}}
{{- if .Values.deployment.resources -}}
  {{- if and .Values.deployment.resources.limits .Values.deployment.resources.requests -}}
    {{- if .Values.deployment.resources.limits.cpu -}}
      {{- if .Values.deployment.resources.requests.cpu -}}
        {{- $limitCPU := .Values.deployment.resources.limits.cpu | toString -}}
        {{- $requestCPU := .Values.deployment.resources.requests.cpu | toString -}}
        {{- if not (regexMatch "^[0-9]+(m|[0-9]*\\.?[0-9]*)?$" $limitCPU) -}}
          {{- fail "ERROR: Invalid CPU limit format. Use formats like '500m', '1', '1.5', etc.\nCurrent value: " $limitCPU -}}
        {{- end -}}
        {{- if not (regexMatch "^[0-9]+(m|[0-9]*\\.?[0-9]*)?$" $requestCPU) -}}
          {{- fail "ERROR: Invalid CPU request format. Use formats like '250m', '0.5', '1', etc.\nCurrent value: " $requestCPU -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
    {{- if .Values.deployment.resources.limits.memory -}}
      {{- if .Values.deployment.resources.requests.memory -}}
        {{- $limitMemory := .Values.deployment.resources.limits.memory | toString -}}
        {{- $requestMemory := .Values.deployment.resources.requests.memory | toString -}}
        {{- if not (regexMatch "^[0-9]+[KMGT]?i?$" $limitMemory) -}}
          {{- fail "ERROR: Invalid memory limit format. Use formats like '512Mi', '1Gi', '2G', etc.\nCurrent value: " $limitMemory -}}
        {{- end -}}
        {{- if not (regexMatch "^[0-9]+[KMGT]?i?$" $requestMemory) -}}
          {{- fail "ERROR: Invalid memory request format. Use formats like '256Mi', '512Mi', '1Gi', etc.\nCurrent value: " $requestMemory -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate HPA configuration
*/}}
{{- define "medplum.validateHPA" -}}
{{- if .Values.deployment.autoscaling.enabled -}}
  {{- $minReplicas := .Values.deployment.autoscaling.minReplicas | default 1 -}}
  {{- $maxReplicas := .Values.deployment.autoscaling.maxReplicas | default 10 -}}
  {{- if lt $maxReplicas $minReplicas -}}
    {{- fail "ERROR: HPA maxReplicas must be greater than or equal to minReplicas.\nCurrent values: minReplicas=" $minReplicas " maxReplicas=" $maxReplicas -}}
  {{- end -}}
  {{- if lt $minReplicas 1 -}}
    {{- fail "ERROR: HPA minReplicas must be at least 1.\nCurrent value: " $minReplicas -}}
  {{- end -}}
  {{- if gt $maxReplicas 100 -}}
    {{- fail "WARNING: HPA maxReplicas is very high (" $maxReplicas "). Consider if this is intentional to avoid excessive resource usage." -}}
  {{- end -}}
  {{- $cpuThreshold := .Values.deployment.autoscaling.targetCPUUtilizationPercentage -}}
  {{- $memoryThreshold := .Values.deployment.autoscaling.targetMemoryUtilizationPercentage -}}
  {{- if and $cpuThreshold (or (lt $cpuThreshold 1) (gt $cpuThreshold 100)) -}}
    {{- fail "ERROR: CPU utilization threshold must be between 1 and 100.\nCurrent value: " $cpuThreshold -}}
  {{- end -}}
  {{- if and $memoryThreshold (or (lt $memoryThreshold 1) (gt $memoryThreshold 100)) -}}
    {{- fail "ERROR: Memory utilization threshold must be between 1 and 100.\nCurrent value: " $memoryThreshold -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate ingress configuration
*/}}
{{- define "medplum.validateIngress" -}}
{{- if .Values.ingress.deploy -}}
  {{- if not .Values.ingress.domain -}}
    {{- fail "ERROR: Domain is required when ingress is enabled.\nPlease set 'ingress.domain' in your values.yaml file.\nExample: ingress.domain: \"medplum.example.com\"" -}}
  {{- end -}}
  {{- $domain := .Values.ingress.domain | toString -}}
  {{- if not (regexMatch "^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*$" $domain) -}}
    {{- fail "ERROR: Invalid domain format. Please provide a valid domain name.\nExample: medplum.example.com\nCurrent value: " $domain -}}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Validate cloud provider configuration
*/}}
{{- define "medplum.validateCloudProvider" -}}
{{- $supportedProviders := list "gcp" -}}
{{- if not (has .Values.global.cloudProvider $supportedProviders) -}}
  {{- fail "ERROR: Unsupported cloud provider '" .Values.global.cloudProvider "'.\nSupported providers: " (join ", " $supportedProviders) "\nRoadmap includes: aws, azure" -}}
{{- end -}}
{{- end }}

{{/*
Run all validations - call this from main templates
*/}}
{{- define "medplum.validateAll" -}}
{{- include "medplum.validateCloudProvider" . -}}
{{- include "medplum.validateGCPConfig" . -}}
{{- include "medplum.validateServiceAccount" . -}}
{{- include "medplum.validateResources" . -}}
{{- include "medplum.validateHPA" . -}}
{{- include "medplum.validateIngress" . -}}
{{- end }}


