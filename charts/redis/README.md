# redis Helm Chart

## Overview
This chart vendors the upstream Bitnami `redis` chart and provides a thin wrapper for environment‑specific configuration plus any platform‑level service objects (e.g. an ops Service) required for operational access.

## Upstream Dependency
Declared in `Chart.yaml`:
```
dependencies:
  - name: redis
    version: 21.2.7
    repository: https://charts.bitnami.com/bitnami
```
Pinning the upstream version ensures reproducible deployments and controlled upgrades.

## Features
- Upstream Bitnami Redis (standalone or HA depending on values you extend)
- Environment overrides (`values.dev-01.yaml`, `values.stag-01.yaml`, etc.)
- Simple default (auth disabled) – adjust before production
- Placeholder for ops‑only Service (`templates/ops-svc.yaml`) if you need restricted network access / monitoring endpoints

## Security & Auth
Authentication is currently disabled via:
```
redis:
  auth:
    enabled: false
```
Before using in shared or production environments enable AUTH and supply a password/secret (sealed or External Secrets). Example override:
```
redis:
  auth:
    enabled: true
    existingSecret: redis-auth
    existingSecretPasswordKey: redis-password
```

## Common Value Adjustments (extend as needed)
| Key | Purpose |
|-----|---------|
| `redis.auth.enabled` | Enable password authentication |
| `redis.replica.replicaCount` | Scale read replicas (if using replication) |
| `redis.master.resources` / `redis.replica.resources` | Resource requests/limits |
| `redis.persistence.enabled` / `size` | Durable storage |
| `redis.networkPolicy.enabled` | Restrict traffic |
| `redis.tls.enabled` | TLS in transit (provide certs) |

(Refer to upstream Bitnami Redis chart docs for full matrix of options.)

## Deployment (direct Helm)
```bash
helm dependency update ./redis
helm upgrade --install redis ./redis -f redis/values.dev-01.yaml -n data --create-namespace
```
In GitOps flow, the `app-of-apps` chart toggles inclusion via `redis.enable: true` in the environment values.

## Operational Notes
- Enable persistence for any state you cannot easily recreate.
- Set resource requests to avoid eviction and enable reliable scheduling.
- Apply NetworkPolicies to restrict access to only namespaces/workloads needing Redis.
- Enable metrics exporter (upstream option) for integration with monitoring stack.

## Scaling & HA
For HA, configure the upstream sentinel / replication settings; this wrapper intentionally leaves that choice to environment overrides.

## Upgrades
1. Review upstream release notes for breaking changes.
2. Bump dependency version in `Chart.yaml`.
3. Run `helm dependency update ./redis`.
4. Test in lower environment before promoting.

## Adding Platform Customizations
Add new templates under `templates/` (e.g., NetworkPolicy, ServiceMonitor) guarded by values flags to keep base lean.

## License
Internal use unless otherwise specified.
