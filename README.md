# sa-platform-gitops

Repositorio GitOps del sistema `sa-platform` (Práctica 8, Software
Avanzado — USAC). Independiente del repositorio de código
(`Pr-cticas-SA-B-201800678`, carpeta `P6`/`P8`): este repo contiene
**solo** manifiestos declarativos, y es la única fuente de verdad que
ArgoCD sincroniza contra el clúster.

## Qué hay aquí

```
charts/sa-platform/          Chart de Helm (copia derivada de P6/charts/sa-platform,
                              ya con Rollout/AnalysisTemplate de Argo Rollouts y sin
                              Namespace/ResourceQuota/LimitRange/RBAC/Secret propios)
  values.yaml                 Base común a ambos ambientes
  values-staging.yaml         Ambiente staging -- el PR automático del pipeline
                              edita SOLO este archivo (bump de image.tag)
  values-prod.yaml            Ambiente prod -- mismo mecanismo, pero el PR
                              exige merge manual (gate de promoción)
sealed-secrets/staging/       SealedSecret cifrados del ambiente staging
sealed-secrets/prod/          SealedSecret cifrados del ambiente prod
argocd/application-staging.yaml   Application de ArgoCD (staging)
argocd/application-prod.yaml      Application de ArgoCD (prod)
```

## Regla de oro

- **Nadie edita este repo a mano**, salvo:
  1. El pipeline (`.github/workflows/p8-gitops.yml` del repo de código),
     que abre un PR cambiando únicamente `image.tag` en
     `values-staging.yaml`/`values-prod.yaml`.
  2. `P8/sealed-secrets/seal-secrets.sh` (del repo de código), que
     regenera los `SealedSecret` de `sealed-secrets/<ambiente>/`.
  3. Cambios de **estructura** del chart (nuevas políticas, nuevos pasos
     de canary, etc.) se sincronizan manualmente desde
     `P6/charts/sa-platform` cuando cambian — ver
     `P8/MANUAL_TECNICO.md` del repo de código.
- **Ningún secreto en texto plano**: todo valor sensible vive como
  `SealedSecret` (ciphertext), nunca como `Secret` ni como valor plano en
  ningún `values-*.yaml`.
- **ArgoCD es el único componente que aplica cambios al clúster** — este
  repo nunca se instala con `helm install`/`helm upgrade` a mano.

Ver el repositorio de código para el resto de la documentación (diagramas,
costos, manual técnico, informe de incidente).
