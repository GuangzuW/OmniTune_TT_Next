{{- define "omnitune.name" -}}
{{- default .Chart.Name .Values.nameOverride -}}
{{- end -}}

{{- define "omnitune.labels" -}}
app.kubernetes.io/name: {{ include "omnitune.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* Build a full image reference: [registry/]repository:tag */}}
{{- define "omnitune.image" -}}
{{- $reg := .root.Values.image.registry -}}
{{- if $reg -}}
{{ $reg }}/{{ .repo }}:{{ .root.Values.image.tag }}
{{- else -}}
{{ .repo }}:{{ .root.Values.image.tag }}
{{- end -}}
{{- end -}}
