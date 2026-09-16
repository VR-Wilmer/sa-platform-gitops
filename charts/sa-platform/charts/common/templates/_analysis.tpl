{{/*
AnalysisTemplate (Practica 8, requisito "Validacion automatizada como
puerta de calidad"): condiciona cada paso de promocion del canary
(common.rollout) a una sola senal, sin pruebas de humo ni de carga (fuera
de alcance por decision explicita, ver P8/docs/costos-y-consideraciones.md)
-- el provider nativo "web" de Argo Rollouts hace una peticion HTTP
periodica contra /health del Service canario (common.rolloutServices) y
compara el codigo de estado devuelto. Si no se especifica "jsonPath", Argo
Rollouts usa como resultado el propio codigo HTTP de la respuesta, asi que
no hace falta conocer ni parsear el cuerpo de /health de cada servicio.

count/interval: 3 mediciones cada 10s (~30s de ventana por paso). Con
failureLimit en 0 (valor por defecto de Argo Rollouts), la primera
medicion fallida marca el AnalysisRun como Failed y el Rollout aborta de
inmediato -- no espera a agotar las 3 mediciones para revertir.
*/}}
{{- define "common.analysistemplate" -}}
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: {{ include "common.fullname" . }}-analysis
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  metrics:
    - name: health-check
      count: 3
      interval: 10s
      successCondition: result == 200
      failureCondition: result != 200
      provider:
        web:
          url: "http://{{ include "common.fullname" . }}-canary.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.port }}{{ .Values.probes.readiness.path }}"
          timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds | default 3 }}
{{- end -}}
