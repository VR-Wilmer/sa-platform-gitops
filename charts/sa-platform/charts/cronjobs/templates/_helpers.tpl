{{/*
Labels para un cronjob especifico. Recibe un dict {root: $, name: "..."}
porque un named template solo toma un argumento, y este subchart define DOS
cronjobs (a diferencia de los subcharts de servicio, que solo tienen un
nombre fijo via nameOverride).
*/}}
{{- define "cronjobs.labels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/part-of: sa-platform
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end -}}

{{- define "cronjobs.selectorLabels" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
{{- end -}}
