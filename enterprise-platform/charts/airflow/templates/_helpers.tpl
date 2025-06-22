{{/*
Expand the name of the chart.
*/}}
{{- define "airflow.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "airflow.fullname" -}}
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
{{- define "airflow.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "airflow.labels" -}}
helm.sh/chart: {{ include "airflow.chart" . }}
{{ include "airflow.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.global }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "airflow.selectorLabels" -}}
app.kubernetes.io/name: {{ include "airflow.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels
*/}}
{{- define "airflow.componentLabels" -}}
{{ include "airflow.labels" . }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "airflow.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "airflow.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the worker service account to use
*/}}
{{- define "airflow.workerServiceAccountName" -}}
{{- printf "%s-worker" (include "airflow.serviceAccountName" .) }}
{{- end }}

{{/*
Database connection string
*/}}
{{- define "airflow.databaseConnectionString" -}}
{{- if .Values.database.existingSecret }}
postgresql://{{ .Values.database.username }}:$(POSTGRES_PASSWORD)@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.database }}
{{- else }}
postgresql://{{ .Values.database.username }}:$(POSTGRES_PASSWORD)@{{ .Values.database.host }}:{{ .Values.database.port }}/{{ .Values.database.database }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "airflow.imagePullSecrets" -}}
{{- if .Values.global }}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Security context
*/}}
{{- define "airflow.securityContext" -}}
{{- if .Values.global }}
{{- if .Values.global.openshift }}
{{- if .Values.global.openshift.enabled }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 2 }}
{{- end }}
{{- end }}
{{- else }}
securityContext:
  {{- toYaml .Values.securityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Pod security context
*/}}
{{- define "airflow.podSecurityContext" -}}
{{- if .Values.global }}
{{- if .Values.global.openshift }}
{{- if .Values.global.openshift.enabled }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}
{{- else }}
securityContext:
  {{- toYaml .Values.podSecurityContext | nindent 2 }}
{{- end }}
{{- end }}

{{/*
OpenShift SCC annotations
*/}}
{{- define "airflow.sccAnnotations" -}}
{{- if .Values.global }}
{{- if .Values.global.openshift }}
{{- if .Values.global.openshift.enabled }}
annotations:
  openshift.io/scc: {{ .Values.global.openshift.scc | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Prometheus metrics annotations
*/}}
{{- define "airflow.metricsAnnotations" -}}
{{- if .Values.metrics.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.metrics.port | quote }}
prometheus.io/path: {{ .Values.metrics.path | quote }}
{{- end }}
{{- end }}

{{/*
Storage class
*/}}
{{- define "airflow.storageClass" -}}
{{- if .Values.global }}
{{- if .Values.global.useBYOS }}
{{- .Values.global.storageClass | quote }}
{{- else }}
{{- .Values.storage.logs.storageClass | quote }}
{{- end }}
{{- else }}
{{- .Values.storage.logs.storageClass | quote }}
{{- end }}
{{- end }}

{{/*
Airflow configuration
*/}}
{{- define "airflow.configMap" -}}
{{- $config := .Values.config }}
{{- range $section, $settings := $config }}
[{{ $section }}]
{{- range $key, $value := $settings }}
{{ $key }} = {{ $value }}
{{- end }}
{{- end }}
{{- end }}