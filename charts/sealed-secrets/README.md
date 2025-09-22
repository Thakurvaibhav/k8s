# sealed-secrets Helm Chart

## Overview
This chart vendors the upstream Bitnami Sealed Secrets controller (as a Helm dependency) and optionally provisions **global platform secrets** that can be consumed by multiple applications across environments.

It is intended to be deployed via the Argo CD **App‑of‑Apps** pattern (root application enables or disables this chart). Application‑specific secrets belong in each application chart/repo; only cross‑cutting or organization‑wide credentials should live here.

## Key Features
- Bundles upstream controller (dependency: `sealed-secrets` alias `sealedsecrets`)
- Optional global secret template (`globalExampleSecret`) enabled per environment
- Environment override files (`values.dev-01.yaml`, `values.stag-01.yaml`, etc.)
- GitOps friendly: declarative controller + sealed secret manifests
- Supports user‑supplied controller key pair for deterministic sealing (recommended)

## When To Put a Secret Here
| Location | Use Case |
|----------|----------|
| This chart (global) | Shared certs, platform API tokens, object storage creds used by multiple charts/services |
| Individual app chart | Secret only one workload uses (e.g., service specific API key) |

## Values (Excerpt)
```
globalExampleSecret:
  enabled: true            # Toggle rendering of the demo global sealed secret
  name: my-global-secret   # Name of the resulting Secret after unsealing
  namespace: my-namespace  # Target namespace for the unsealed Secret
```
The template `templates/sealed-my-global-secret.yaml` renders only when `globalExampleSecret.enabled: true`.

To add more global secrets, replicate the pattern with additional templated SealedSecrets or extend the existing structure (`data.*`).

## Installation (App‑of‑Apps)
The root Argo CD app defines an `Application` pointing at `charts/sealed-secrets`. Syncing that application installs the controller CRDs (if not already present) and any enabled global sealed secrets.

Manual Helm install (for local testing):
```bash
helm dependency update ./sealed-secrets
helm upgrade --install sealed-secrets ./sealed-secrets -n sealed-secrets --create-namespace -f sealed-secrets/values.dev-01.yaml
```

## Providing a User‑Defined Sealing Key (RECOMMENDED)
By default, the controller will generate an ephemeral key pair. For portability (e.g., disaster recovery, identical dev/stage/prod behavior) you should pre‑create and label a key so future rotations are controlled.

### 1. Generate Key Pair
```bash
mkdir -p sealing-key && cd sealing-key
openssl req -x509 -days 3650 -nodes -newkey rsa:4096 \
  -keyout platform-sealing.key \
  -out platform-sealing.crt \
  -subj "/CN=sealed-secret/O=sealed-secret"
```

### 2. Create TLS Secret in Controller Namespace
```bash
kubectl -n sealed-secrets create secret tls platform-sealing-key \
  --cert=platform-sealing.crt --key=platform-sealing.key
```

### 3. Mark It Active
```bash
kubectl -n sealed-secrets label secret platform-sealing-key \
  sealedsecrets.bitnami.com/sealed-secrets-key=active
```
The controller will use the secret labeled `active` for sealing/unsealing. Keep the private key safe (store in a secure vault / backup system).

### 4. Backup the Key Material
Securely archive `platform-sealing.key` and `platform-sealing.crt` (e.g., encrypted storage, KMS‑backed secrets manager). Without the private key you cannot decrypt previously sealed secrets.

### 5. (Optional) Rotate Key
Create a new key pair, label it `active`, remove label from old key. Reseal secrets if rotation policy demands.

## Sealing a Secret Manifest
1. Create a standard Kubernetes Secret manifest (`my-secret.yaml`) WITHOUT committing it to Git.
2. Seal it using the public certificate:
```bash
kubeseal --cert platform-sealing.crt --scope cluster-wide --format yaml < my-secret.yaml > sealed-my-secret.yaml
```
3. Commit only `sealed-my-secret.yaml`.

Scopes you can use:
- `--scope cluster-wide` (default here; secret usable in any namespace)
- `--scope namespace-wide --namespace <ns>`
- `--scope strict --name <name> --namespace <ns>` (most restrictive)

Choose the narrowest scope that fits your use case.

## Adding Additional Global Secrets (Pattern)
Duplicate the template with a guard:
```yaml
{{- if .Values.anotherGlobalSecret.enabled }}
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: {{ .Values.anotherGlobalSecret.name }}
  namespace: {{ .Values.anotherGlobalSecret.namespace }}
spec:
  encryptedData:
    key: {{ .Values.anotherGlobalSecret.data.key }}
  template:
    type: Opaque
{{- end }}
```
Populate encrypted values in environment overrides.

## Flow Summary
1. Generate/maintain controller key (once per cluster or reused across clones).
2. Seal secrets with the public cert.
3. Commit sealed manifests.
4. Argo CD syncs this chart → controller + sealed secrets.
5. Controller unseals at runtime producing standard Secrets.

## Security Notes
- Never commit unsealed `Secret` objects containing plaintext data.
- Treat the private key as highly sensitive; anyone with it can decrypt sealed secrets.
- Rotate keys periodically and reseal if mandated by policy.
- Use namespace/strict scopes for tenant isolation where feasible.

## Troubleshooting
| Symptom | Cause | Action |
|---------|-------|--------|
| Secret not created | Wrong scope vs target namespace | Reseal with correct scope |
| Decryption failed | Wrong controller key (rotated / missing) | Restore original key or reseal with new cert |
| Multiple keys active | Label conflict | Ensure only one secret has `sealed-secrets-key=active` |

## License
Internal use unless stated otherwise.
