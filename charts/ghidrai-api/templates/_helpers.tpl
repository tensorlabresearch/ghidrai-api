{{- define "ghidrai-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ghidrai-api.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "ghidrai-api.name" . -}}
{{- end -}}
{{- end -}}

{{- define "ghidrai-api.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "ghidrai-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ghidrai-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ghidrai-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ghidrai-api.tunnelSecretName" -}}
{{- if .Values.cloudflared.tunnelTokenSecret.create -}}
{{- printf "%s-tunnel-token" (include "ghidrai-api.fullname" .) -}}
{{- else -}}
{{- .Values.cloudflared.tunnelTokenSecret.existingSecret -}}
{{- end -}}
{{- end -}}

