{{/*
Expand the name of the chart.
*/}}
{{- define "spark.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spark.fullname" -}}
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
{{- define "spark.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "spark.labels" -}}
helm.sh/chart: {{ include "spark.chart" . }}
{{ include "spark.selectorLabels" . }}
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
{{- define "spark.selectorLabels" -}}
app.kubernetes.io/name: {{ include "spark.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spark.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "spark.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "spark.imagePullSecrets" -}}
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
{{- define "spark.securityContext" -}}
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
{{- define "spark.podSecurityContext" -}}
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
{{- define "spark.sccAnnotations" -}}
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
{{- define "spark.metricsAnnotations" -}}
{{- if .Values.metrics.enabled }}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.metrics.port | quote }}
prometheus.io/path: {{ .Values.metrics.path | quote }}
{{- end }}
{{- end }}

{{/*
Storage class
*/}}
{{- define "spark.storageClass" -}}
{{- if .Values.global }}
{{- if .Values.global.useBYOS }}
{{- .Values.global.storageClass | quote }}
{{- else }}
{{- .Values.storage.checkpoint.storageClass | quote }}
{{- end }}
{{- else }}
{{- .Values.storage.checkpoint.storageClass | quote }}
{{- end }}
{{- end }}

{{/*
Spark configuration
*/}}
{{- define "spark.configMap" -}}
{{- $config := .Values.config }}
{{- range $key, $value := $config }}
{{- if not (hasPrefix "customConfig" $key) }}
{{ $key }}={{ $value }}
{{- end }}
{{- end }}
{{- if .Values.config.customConfig }}
{{ .Values.config.customConfig }}
{{- end }}
{{- end }}

{{/*
Checkpoint PVC name
*/}}
{{- define "spark.checkpointPvcName" -}}
{{- printf "%s-checkpoint" (include "spark.fullname" .) }}
{{- end }}

{{/*
Scratch PVC name
*/}}
{{- define "spark.scratchPvcName" -}}
{{- printf "%s-scratch" (include "spark.fullname" .) }}
{{- end }}

{{/*
Driver pod template
*/}}
{{- define "spark.driverPodTemplate" -}}
apiVersion: v1
kind: Pod
metadata:
  labels:
    {{- include "spark.labels" . | nindent 4 }}
    app.kubernetes.io/component: driver
    {{- with .Values.podTemplate.driver.metadata.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "spark.metricsAnnotations" . | nindent 4 }}
    {{- with .Values.podTemplate.driver.metadata.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- include "spark.imagePullSecrets" . | nindent 2 }}
  serviceAccountName: {{ include "spark.serviceAccountName" . }}
  {{- include "spark.podSecurityContext" . | nindent 2 }}
  containers:
    - name: spark-kubernetes-driver
      {{- include "spark.securityContext" . | nindent 6 }}
      image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      resources:
        {{- toYaml .Values.resources.driver | nindent 8 }}
      volumeMounts:
        {{- if .Values.storage.checkpoint.enabled }}
        - name: checkpoint-volume
          mountPath: {{ .Values.storage.checkpoint.path }}
        {{- end }}
        {{- if .Values.storage.scratch.enabled }}
        - name: scratch-volume
          mountPath: {{ .Values.storage.scratch.path }}
        {{- end }}
        {{- range .Values.extraVolumeMounts }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          {{- if .subPath }}
          subPath: {{ .subPath }}
          {{- end }}
        {{- end }}
  volumes:
    {{- if .Values.storage.checkpoint.enabled }}
    - name: checkpoint-volume
      persistentVolumeClaim:
        claimName: {{ include "spark.checkpointPvcName" . }}
    {{- end }}
    {{- if .Values.storage.scratch.enabled }}
    - name: scratch-volume
      persistentVolumeClaim:
        claimName: {{ include "spark.scratchPvcName" . }}
    {{- end }}
    {{- range .Values.extraVolumes }}
    - name: {{ .name }}
      {{- toYaml .volume | nindent 6 }}
    {{- end }}
  {{- with .Values.podTemplate.driver.spec.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podTemplate.driver.spec.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podTemplate.driver.spec.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Executor pod template
*/}}
{{- define "spark.executorPodTemplate" -}}
apiVersion: v1
kind: Pod
metadata:
  labels:
    {{- include "spark.labels" . | nindent 4 }}
    app.kubernetes.io/component: executor
    {{- with .Values.podTemplate.executor.metadata.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "spark.metricsAnnotations" . | nindent 4 }}
    {{- with .Values.podTemplate.executor.metadata.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- include "spark.imagePullSecrets" . | nindent 2 }}
  serviceAccountName: {{ include "spark.serviceAccountName" . }}
  {{- include "spark.podSecurityContext" . | nindent 2 }}
  containers:
    - name: spark-kubernetes-executor
      {{- include "spark.securityContext" . | nindent 6 }}
      image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      resources:
        {{- toYaml .Values.resources.executor | nindent 8 }}
      volumeMounts:
        {{- if .Values.storage.checkpoint.enabled }}
        - name: checkpoint-volume
          mountPath: {{ .Values.storage.checkpoint.path }}
        {{- end }}
        {{- if .Values.storage.scratch.enabled }}
        - name: scratch-volume
          mountPath: {{ .Values.storage.scratch.path }}
        {{- end }}
        {{- range .Values.extraVolumeMounts }}
        - name: {{ .name }}
          mountPath: {{ .mountPath }}
          {{- if .subPath }}
          subPath: {{ .subPath }}
          {{- end }}
        {{- end }}
  volumes:
    {{- if .Values.storage.checkpoint.enabled }}
    - name: checkpoint-volume
      persistentVolumeClaim:
        claimName: {{ include "spark.checkpointPvcName" . }}
    {{- end }}
    {{- if .Values.storage.scratch.enabled }}
    - name: scratch-volume
      persistentVolumeClaim:
        claimName: {{ include "spark.scratchPvcName" . }}
    {{- end }}
    {{- range .Values.extraVolumes }}
    - name: {{ .name }}
      {{- toYaml .volume | nindent 6 }}
    {{- end }}
  {{- with .Values.podTemplate.executor.spec.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podTemplate.executor.spec.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.podTemplate.executor.spec.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}