# SealedSecret de staging

Vacío hasta correr `P8/sealed-secrets/seal-secrets.sh staging sa-p8-staging ../sa-platform-gitops`
contra el clúster real (necesita el certificado público del controlador
de Sealed Secrets ya instalado por Terraform). Los archivos `*.yaml` que
ese script genera aquí son **ciphertext** — seguros de versionar, solo el
controlador del clúster puede descifrarlos. Ver `P8/MANUAL_TECNICO.md`.
