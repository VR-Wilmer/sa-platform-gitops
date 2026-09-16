{{/*
ConfigMap: toda variable NO sensible (requisito B). Las claves vienen de
.Values.configMap.data, un mapa simple {NOMBRE: valor} definido por cada
subchart de servicio -- se recorre con range porque el numero de variables
varia de un servicio a otro (identidad no tiene topicos Kafka, tickets si).
*/}}
{{- define "common.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.configMap.data }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end -}}

{{/*
Secret: a partir de P8, este chart YA NO crea el objeto Secret (requisito
"Gestion de secretos" de la Practica 8). El controlador de Sealed Secrets
lo materializa a partir del SealedSecret versionado en el repo GitOps
(P8/sealed-secrets/), con el mismo nombre que "common.fullname" -- por eso
el Deployment/Rollout sigue haciendo "secretRef: name: <fullname>" sin
ningun cambio, solo deja de ser este chart quien lo crea. Ver
P8/sealed-secrets/seal-secrets.sh y P8/docs/costos-y-consideraciones.md.
*/}}
