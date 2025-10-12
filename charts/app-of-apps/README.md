# app-of-apps Helm Chart

## Overview
Implements an Argo CD "App of Apps" pattern to bootstrap multiple application/infra charts from a single root.

## Features
- Central orchestration of environment application set
- Environment specific values overrides
- Simplifies onboarding and promotion flows

## Usage
Define child Applications or Projects under `templates/`. Each environment file (`values.*.yaml`) can toggle inclusions or set sources.

## Deploy
```bash
helm upgrade --install app-of-apps ./app-of-apps -f values.dev-01.yaml -n argocd
```

## Recommended
- Use sync waves and hooks in child apps for ordering
- Lock chart versions for reproducibility

## Related Platform Documentation
The following higher‑level design documents describe how this chart participates in the overall platform. They are maintained centrally under `docs/` to avoid drift.

| Topic | Doc | Purpose / How This Chart Fits |
|-------|-----|--------------------------------|
| Observability (metrics, logs, traces) | [observability.md](../../docs/observability.md) | Enable/disable `monitoring`, `logging`, `jaeger` blocks per environment; promotion moves global + per‑cluster components safely. |
| Traffic Management (Gateway, certs, DNS) | [traffic-management.md](../../docs/traffic-management.md) | Sync waves ensure `sealed-secrets` → `cert-manager` → `envoyGateway` → `externalDNS` ordering defined here. |
| Policy & Compliance (Kyverno + Checkov) | [compliance.md](../../docs/compliance.md) | Progressive `kyverno` + `kyvernoPolicies` enablement (Audit → Enforce) coordinated via environment value files. |

### Component Matrix
See [What Runs Where](./what-runs-where.md) for a generated per‑cluster component enablement and effective `targetRevision` matrix (disabled components marked with ❌). Regenerate via `scripts/what-runs-where.sh` after changing `values.*.yaml` files.

### Quick Mapping (Values → Docs)
- `monitoring.enable`, `logging.enable`, `jaeger.enable` → Observability deployment stages
- `envoyGateway.enable`, `certManager.enable`, `externalDNS.enable`, `sealedSecrets.enable` → Traffic stack sync waves
- `kyverno.enable` → Compliance progressive rollout

Keep detailed architectural rationale in the central docs; this README focuses on how to wire components together via flags & sync ordering.
