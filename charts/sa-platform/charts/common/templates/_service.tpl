{{- define "common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
{{- end -}}

{{/*
Services canary/stable (Practica 8, entrega progresiva): Argo Rollouts
necesita un Service que seleccione SOLO los pods canary y otro que
seleccione SOLO los pods stable para poder dirigir el AnalysisTemplate
(common.analysistemplate) unicamente contra la version candidata. El
selector inicial es el mismo de common.service -- el controlador de Argo
Rollouts inyecta/mantiene automaticamente la etiqueta adicional
"rollouts-pod-template-hash" en estos dos Service en cuanto el Rollout
(common.rollout) los referencia via canaryService/stableService, sin que
este chart tenga que calcularla.
*/}}
{{- define "common.rolloutServices" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-canary
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}-stable
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
      protocol: TCP
{{- end -}}

{{/*
Ingress: solo lo declara gateway (unica puerta de entrada al cluster,
requisito E). El resto de subcharts deja ingress.enabled=false por defecto y
esta plantilla no renderiza nada para ellos.
*/}}
{{- define "common.ingress" -}}
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className | default "nginx" | quote }}
  rules:
    - host: {{ required "ingress.host es obligatorio cuando ingress.enabled=true" .Values.ingress.host | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end -}}
{{- end -}}
