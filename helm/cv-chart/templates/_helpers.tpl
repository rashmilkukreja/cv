{{- define "cv-app.name" -}}
cv-app
{{- end }}

{{- define "cv-app.fullname" -}}
{{ .Release.Name }}-cv-app
{{- end }}
