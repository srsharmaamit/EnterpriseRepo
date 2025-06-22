{{/*
Expand the name of the chart.
*/}}
{{- define "enterprise-platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "enterprise-platform.fullname" -}}
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
{{- define "enterprise-platform.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "enterprise-platform.labels" -}}
helm.sh/chart: {{ include "enterprise-platform.chart" . }}
{{ include "enterprise-platform.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "enterprise-platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "enterprise-platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "enterprise-platform.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.create }}
{{- default (include "enterprise-platform.fullname" .) .Values.global.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.global.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common image pull secrets
*/}}
{{- define "enterprise-platform.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
PostgreSQL fullname
*/}}
{{- define "enterprise-platform.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "enterprise-platform.fullname" .) }}
{{- end }}

{{/*
Airflow fullname
*/}}
{{- define "enterprise-platform.airflow.fullname" -}}
{{- printf "%s-airflow" (include "enterprise-platform.fullname" .) }}
{{- end }}

{{/*
Spark fullname
*/}}
{{- define "enterprise-platform.spark.fullname" -}}
{{- printf "%s-spark" (include "enterprise-platform.fullname" .) }}
{{- end }}

{{/*
Spark service account name
*/}}
{{- define "enterprise-platform.spark.serviceAccountName" -}}
{{- if .Values.spark.serviceAccount.create }}
{{- default (printf "%s-spark" (include "enterprise-platform.fullname" .)) .Values.spark.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.spark.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Environment-specific resource overrides
*/}}
{{- define "enterprise-platform.resources" -}}
{{- $env := .Values.global.environment | default "dev" }}
{{- if hasKey .Values.environments $env }}
{{- $envConfig := index .Values.environments $env }}
{{- if $envConfig.resources }}
{{ toYaml $envConfig.resources }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Storage class helper
*/}}
{{- define "enterprise-platform.storageClass" -}}
{{- if .Values.global.useBYOS }}
{{- .Values.global.storageClass | quote }}
{{- else }}
{{- "" }}
{{- end }}
{{- end }}

{{/*
Security context helper for OpenShift
*/}}
{{- define "enterprise-platform.securityContext" -}}
{{- if .Values.global.openshift.enabled }}
securityContext:
  {{- toYaml .Values.global.securityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod security context helper for OpenShift
*/}}
{{- define "enterprise-platform.podSecurityContext" -}}
{{- if .Values.global.openshift.enabled }}
securityContext:
  {{- toYaml .Values.global.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
OpenShift SCC annotations
*/}}
{{- define "enterprise-platform.sccAnnotations" -}}
{{- if .Values.global.openshift.enabled }}
annotations:
  openshift.io/scc: {{ .Values.global.openshift.scc | quote }}
{{- end }}
{{- end }}

{{/*
Prometheus metrics annotations
*/}}
{{- define "enterprise-platform.metricsAnnotations" -}}
prometheus.io/scrape: "true"
prometheus.io/path: "/metrics"
{{- end }}