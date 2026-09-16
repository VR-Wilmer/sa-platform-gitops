{{/*
Labels aplicados a los objetos que vive directamente en el chart padre
(ResourceQuota, LimitRange, NetworkPolicies, el Job de topicos Kafka) -- los
objetos de cada microservicio usan su propio "common.labels" (ver
charts/common/templates/_helpers.tpl).
*/}}
{{- define "sa-platform.labels" -}}
app.kubernetes.io/part-of: sa-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | quote }}
{{- end -}}

{{/*
Nombre corto usado por el Job de creacion de topicos y sus RBAC asociados.
*/}}
{{- define "sa-platform.kafkaTopicsJobName" -}}
kafka-topics-init
{{- end -}}
