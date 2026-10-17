{{/*
AnalysisTemplate -- Practica 10: canary gobernado por METRICAS REALES.

Hasta la Practica 9 el analisis era "provider: web" contra /ready del
Service canario: una prueba sintetica que solo responde "el proceso esta
vivo", nunca "los usuarios estan siendo bien atendidos". Una version que
responde /ready pero tarda 2s en crear un ticket, o que falla el 30% de las
peticiones reales, pasaba el analisis sin objecion. Ahora el analisis
consulta Prometheus sobre el trafico real que recibe la version candidata
(y SOLO ella):

  - rollouts_pod_template_hash = argumento canary-hash: el PodMonitor
    (observabilidad/manifests/podmonitor-sa-platform.yaml) copia la
    etiqueta rollouts-pod-template-hash de cada pod a sus series, y el
    Rollout pasa el hash de la version candidata como argumento
    (valueFrom.podTemplateHashValue: Latest). Asi la consulta nunca mezcla
    el trafico del estable con el del canary.
  - sa_http_server_duration_seconds: histograma propio que exponen los 5
    servicios (P6/<servicio>/src/observability/httpMetrics.ts y
    asignacion-service/app/observability.py), mismo nombre y etiquetas.

Tres metricas, las tres deben pasar:
  1. trafico-canary: sin evidencia no hay promocion. Si la candidata no
     recibio trafico en la ventana, no hay nada que juzgar y el analisis
     falla en vez de aprobar "a ciegas".
  2. tasa-error: proporcion de respuestas 5xx < umbral (global.canary).
  3. latencia-p95: percentil 95 de duracion < umbral (global.canary).

"or vector(0)" en 2 y 3: sin errores la serie de 5xx no existe (y
histogram_quantile sin datos no devuelve nada) -- se traduce a 0 para no
abortar por "sin resultado". Un minuto sin NINGUNA peticion (servicios de
poco trafico como asignacion-service, que solo recibe una llamada por
ticket creado) daba 0/0 = NaN, que no cumple ni la condicion de exito ni
la de fallo y dejaba el AnalysisRun "Inconclusive" (observado en el primer
despliegue de P10): "> 0" en el denominador y ">= 0" en el p95 descartan
el NaN. La metrica 1 es la que impide que esos 0 oculten una candidata sin
trafico.

count/interval/failureLimit: 4 mediciones cada 30s (2 min de evidencia por
paso, ventana [1m] en cada una). failureLimit 1: una medicion mala aislada
(p. ej. el primer arranque en frio) se tolera, dos no -- el AnalysisRun
pasa a Failed y Argo Rollouts aborta y devuelve el 100% al estable sin
intervencion humana.
*/}}
{{- define "common.analysistemplate" -}}
{{- $sel := printf "namespace=%q, service=%q, rollouts_pod_template_hash=\"{{args.canary-hash}}\"" .Release.Namespace (include "common.name" .) -}}
{{- $canary := .Values.global.canary -}}
{{- $prom := .Values.global.observabilidad.prometheusAddress -}}
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: {{ include "common.fullname" . }}-analysis
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  args:
    - name: canary-hash
  metrics:
    - name: trafico-canary
      interval: 30s
      count: 4
      failureLimit: 1
      successCondition: result[0] > 0
      failureCondition: result[0] <= 0
      provider:
        prometheus:
          address: {{ $prom | quote }}
          query: |
            sum(rate(sa_http_server_duration_seconds_count{ {{- $sel -}} }[1m])) or vector(0)
    - name: tasa-error
      interval: 30s
      count: 4
      failureLimit: 1
      successCondition: result[0] < {{ $canary.maxErrorRate }}
      failureCondition: result[0] >= {{ $canary.maxErrorRate }}
      provider:
        prometheus:
          address: {{ $prom | quote }}
          query: |
            (
              (sum(rate(sa_http_server_duration_seconds_count{ {{- $sel -}}, status_code=~"5.."}[1m])) or vector(0))
              /
              (sum(rate(sa_http_server_duration_seconds_count{ {{- $sel -}} }[1m])) > 0)
            ) or vector(0)
    - name: latencia-p95
      interval: 30s
      count: 4
      failureLimit: 1
      successCondition: result[0] < {{ $canary.maxP95Seconds }}
      failureCondition: result[0] >= {{ $canary.maxP95Seconds }}
      provider:
        prometheus:
          address: {{ $prom | quote }}
          query: |
            (histogram_quantile(0.95, sum by (le) (rate(sa_http_server_duration_seconds_bucket{ {{- $sel -}} }[1m]))) >= 0) or vector(0)
{{- end -}}
