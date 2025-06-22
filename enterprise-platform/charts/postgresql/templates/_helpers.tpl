{{/*
Expand the name of the chart.
*/}}
{{- define "postgresql.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "postgresql.fullname" -}}
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
{{- define "postgresql.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "postgresql.labels" -}}
helm.sh/chart: {{ include "postgresql.chart" . }}
{{ include "postgresql.selectorLabels" . }}
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
{{- define "postgresql.selectorLabels" -}}
app.kubernetes.io/name: {{ include "postgresql.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "postgresql.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "postgresql.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "postgresql.secretName" -}}
{{- if .Values.database.existingSecret }}
{{- .Values.database.existingSecret }}
{{- else }}
{{- printf "%s-credentials" (include "postgresql.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "postgresql.imagePullSecrets" -}}
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
{{- define "postgresql.securityContext" -}}
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
{{- define "postgresql.podSecurityContext" -}}
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
{{- define "postgresql.sccAnnotations" -}}
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
{{- define "postgresql.metricsAnnotations" -}}
{{- if .Values.metrics.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.metrics.port | quote }}
prometheus.io/path: "/metrics"
{{- end }}
{{- end }}

{{/*
Storage class
*/}}
{{- define "postgresql.storageClass" -}}
{{- if .Values.global }}
{{- if .Values.global.useBYOS }}
{{- .Values.global.storageClass | quote }}
{{- else }}
{{- .Values.persistence.storageClass | quote }}
{{- end }}
{{- else }}
{{- .Values.persistence.storageClass | quote }}
{{- end }}
{{- end }}

{{/*
Generate database password
*/}}
{{- define "postgresql.generatePassword" -}}
{{- if .Values.database.password }}
{{- .Values.database.password }}
{{- else }}
{{- randAlphaNum 16 }}
{{- end }}
{{- end }}

{{/*
PostgreSQL configuration
*/}}
{{- define "postgresql.configMap" -}}
# PostgreSQL Configuration
listen_addresses = '{{ .Values.config.listenAddresses }}'
port = {{ .Values.config.port }}
max_connections = {{ .Values.config.maxConnections }}

# Memory Settings
shared_buffers = '{{ .Values.config.sharedBuffers }}'
effective_cache_size = '{{ .Values.config.effectiveCacheSize }}'
work_mem = '{{ .Values.config.workMem }}'
maintenance_work_mem = '{{ .Values.config.maintenanceWorkMem }}'

# WAL Settings
wal_buffers = '{{ .Values.config.walBuffers }}'
checkpoint_completion_target = {{ .Values.config.checkpointCompletionTarget }}
max_wal_size = '{{ .Values.config.maxWalSize }}'
min_wal_size = '{{ .Values.config.minWalSize }}'

# Query Planner Settings
random_page_cost = {{ .Values.config.randomPageCost }}
effective_io_concurrency = {{ .Values.config.effectiveIoConcurrency }}

# Logging Settings
log_destination = '{{ .Values.config.logDestination }}'
logging_collector = {{ .Values.config.loggingCollector }}
log_directory = '{{ .Values.config.logDirectory }}'
log_filename = '{{ .Values.config.logFilename }}'
log_truncate_on_rotation = {{ .Values.config.logTruncateOnRotation }}
log_rotation_age = '{{ .Values.config.logRotationAge }}'
log_rotation_size = '{{ .Values.config.logRotationSize }}'
log_min_duration_statement = {{ .Values.config.logMinDurationStatement }}
log_line_prefix = '{{ .Values.config.logLinePrefix }}'
log_lock_waits = {{ .Values.config.logLockWaits }}
log_statement = '{{ .Values.config.logStatement }}'
log_temp_files = {{ .Values.config.logTempFiles }}

# Custom Configuration
{{- if .Values.config.customConfig }}
{{ .Values.config.customConfig }}
{{- end }}
{{- end }}