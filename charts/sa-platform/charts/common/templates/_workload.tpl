{{/*
Rollout (Practica 8: entrega progresiva). Reemplaza al Deployment de P5/P6
-- mismo pod template (probes, securityContext, resources), pero con una
estrategia canary de 3 pasos de promocion (20% / 50% / 100%), cada uno de
los dos primeros condicionado al AnalysisTemplate (common.analysistemplate)
contra el Service canario (common.rolloutServices). Si el analisis falla,
Argo Rollouts aborta y devuelve el peso a 0 automaticamente -- el 100% del
trafico real nunca llega a tocar la version defectuosa.
*/}}
{{- define "common.rollout" -}}
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  {{- if .Values.hpa.enabled }}
  replicas: {{ .Values.hpa.minReplicas }}
  {{- else }}
  replicas: {{ .Values.replicaCount | default 2 }}
  {{- end }}
  strategy:
    canary:
      canaryService: {{ include "common.fullname" . }}-canary
      stableService: {{ include "common.fullname" . }}-stable
      steps:
        - setWeight: 20
        - analysis:
            templates:
              - templateName: {{ include "common.fullname" . }}-analysis
        - pause: { duration: 30s }
        - setWeight: 50
        - analysis:
            templates:
              - templateName: {{ include "common.fullname" . }}-analysis
        - pause: { duration: 30s }
        - setWeight: 100
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.labels" . | nindent 8 }}
      annotations:
        # Fuerza un rollout cuando cambia el ConfigMap (requisito B): al
        # cambiar el hash, el Pod template cambia, y Argo Rollouts dispara
        # una nueva version canary aunque la imagen siga igual. No hay
        # checksum/secret: el Secret ya no lo renderiza este chart (lo
        # materializa Sealed Secrets, ver _config.tpl), asi que no hay
        # contenido en texto plano aqui que hashear.
        checksum/config: {{ include "common.configmap" . | sha256sum }}
    spec:
      serviceAccountName: {{ include "common.serviceAccountName" . }}
      {{- if and .Values.antiAffinity .Values.antiAffinity.enabled }}
      # Practica 9 (resiliencia ante perdida de nodo): "preferred", no
      # "required" -- con maxReplicas 5 y solo 2 nodos worker (ci/kind-config.yaml),
      # una anti-afinidad "required" dejaria el 3er+ pod en Pending
      # permanente apenas el HPA escale bajo carga. "preferred" con peso
      # maximo logra el mismo resultado practico mientras hay hueco (el
      # scheduler siempre prefiere el nodo libre cuando no hay conflicto
      # real), sin bloquear el autoescalado.
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels:
                    {{- include "common.selectorLabels" . | nindent 20 }}
      {{- end }}
      securityContext:
        runAsNonRoot: true
        # Kubernetes no puede verificar "non-root" a partir de un USER con
        # nombre simbolico en la imagen (p. ej. USER node): exige un UID
        # numerico explicito aqui. 1000 es el UID del usuario "node" en
        # node:22-alpine y del usuario "app" en las imagenes Python (fijado
        # a proposito con --uid 1000 en sus Dockerfile).
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: {{ include "common.name" . }}
          image: "{{ .Values.image.repository }}:{{ required "image.tag es obligatorio" .Values.image.tag }}"
          {{- /* Idioma real de if/else: "latest" nunca deberia cachearse local, cualquier otro tag (inmutable) si. */}}
          {{- if eq .Values.image.tag "latest" }}
          imagePullPolicy: Always
          {{- else }}
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
          envFrom:
            - configMapRef:
                name: {{ include "common.fullname" . }}
            - secretRef:
                name: {{ include "common.fullname" . }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds }}
            timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds | default 3 }}
            failureThreshold: {{ .Values.probes.liveness.failureThreshold }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path }}
              port: http
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
            timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds | default 3 }}
            failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
          startupProbe:
            # Tolera el arranque lento (conexion a Postgres/Kafka) sin que
            # liveness mate el pod antes de tiempo: mientras startupProbe no
            # pase, liveness/readiness ni se ejecutan.
            httpGet:
              path: {{ .Values.probes.startup.path }}
              port: http
            periodSeconds: {{ .Values.probes.startup.periodSeconds }}
            timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds | default 3 }}
            failureThreshold: {{ .Values.probes.startup.failureThreshold }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        # readOnlyRootFilesystem: true exige un directorio escribible aparte
        # para lo poco que cada runtime pueda necesitar (p. ej. temporales).
        - name: tmp
          emptyDir: {}
{{- end -}}

{{/*
HPA (requisito F): min 2 / max 5 replicas al X% de CPU, parametrizable por
values (dev usa un umbral mas bajo para que la prueba de carga lo cruce facil).
*/}}
{{- define "common.hpa" -}}
{{- if .Values.hpa.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    # Practica 8: apunta al Rollout (no al Deployment) -- Argo Rollouts
    # implementa el subrecurso /scale igual que un Deployment, el HPA no
    # necesita ningun otro cambio.
    apiVersion: argoproj.io/v1alpha1
    kind: Rollout
    name: {{ include "common.fullname" . }}
  minReplicas: {{ .Values.hpa.minReplicas }}
  maxReplicas: {{ .Values.hpa.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPUUtilizationPercentage }}
{{- end }}
{{- end -}}

{{- define "common.pdb" -}}
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.pdb.minAvailable }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end -}}
