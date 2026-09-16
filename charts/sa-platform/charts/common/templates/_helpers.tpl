{{/*
Nombre corto y estable del componente. Se usa nameOverride en vez del nombre
del subchart para que el Service tenga el mismo nombre DNS predecible sin
importar el nombre del release de Helm (p. ej. "identidad-service" en vez de
"sa-platform-identidad-abc123").
*/}}
{{- define "common.name" -}}
{{- .Values.nameOverride | required "nameOverride es obligatorio en cada subchart de servicio" -}}
{{- end -}}

{{/*
fullname = mismo criterio que common.name (nameOverride ya es unico y
estable dentro del namespace sa-p6), asi los ConfigMaps/Secrets/Services de
los 5 subcharts no colisionan entre si sin depender del nombre del release.
*/}}
{{- define "common.fullname" -}}
{{- include "common.name" . -}}
{{- end -}}

{{/*
Labels comunes aplicados a todo objeto generado por este library chart.
*/}}
{{- define "common.labels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: sa-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{/*
Selector labels: subconjunto estable de common.labels usado tanto por
Deployment.spec.selector como por Service.spec.selector (nunca deben cambiar
entre releases, a diferencia de helm.sh/chart).
*/}}
{{- define "common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Nombre del ServiceAccount dedicado de este componente (nunca "default", ver
requisito G de la Practica 6).
*/}}
{{- define "common.serviceAccountName" -}}
{{- include "common.fullname" . -}}
{{- end -}}
