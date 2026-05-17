{{/*
Base app label used by selectors across Deployment, Service, and monitors.
*/}}
{{- define "cv-app.name" -}}
cv-app
{{- end }}

{{/*
Release-scoped resource name. For release "cv", this renders as "cv-cv-app".
*/}}
{{- define "cv-app.fullname" -}}
{{ .Release.Name }}-cv-app
{{- end }}

{{/*
ServiceAccount name selection:
- create=true and name empty: use the release-scoped app name.
- create=false and name empty: use Kubernetes default ServiceAccount.
- name set: use the provided name in either mode.
*/}}
{{- define "cv-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "cv-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end }}
