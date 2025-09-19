# Helm Charts

## Platform in a Box
These charts implement a "Platform in a Box"—a batteries‑included, GitOps driven foundation for operating a Kubernetes platform using the Argo CD App‑of‑Apps pattern. They compose the core traffic, security, observability, data, and enablement layers so teams can onboard applications quickly with consistent guardrails.

## Core Principles
- Git as the single source of truth (no snowflake clusters)
- Declarative, immutable desired state (Helm + Argo CD Applications)
- Layered composition (bootstrap → platform services → workloads)
- Secure by default (sealed / encrypted secrets, least privilege)
- Idempotent & repeatable bootstrap (App‑of‑Apps orchestrates order)
- Progressive enablement (feature flags via values: enable only what you need)
- Environment parity with scoped overrides (values.<env>.yaml)

This top‑level document inventories charts, their relationships, and recommended installation / reconciliation order.

## Inventory
| Chart | Purpose | Depends On / Cooperates With | Key Notes |
|-------|---------|------------------------------|-----------|
| `app-of-apps` | Argo CD App‑of‑Apps root that defines Argo CD `Application` objects for platform components (monitoring, ingress, gateway, secrets, policies, data services, logging). | Argo CD CRDs present in cluster. Optionally Sealed Secrets controller if you enable secret management here. | Toggle components via values: `sealedSecrets`, `ingressController`, `envoyGateway`, `monitoring`, `kyverno`, `redis`, `logging`. |
| `sealed-secrets` | Vendors upstream Bitnami Sealed Secrets controller and (optionally) renders shared/global sealed secrets. | Installed via `app-of-apps` (if `sealedSecrets.enable=true`). Consumed by charts needing encrypted creds (monitoring, external-dns, others). | Supports user‑defined controller key; global secrets only. |
| `envoy-gateway` | Deploys Envoy Gateway (Gateway API) plus custom GatewayClasses, Gateways, Routes, security & proxy policies. | Kubernetes >=1.27, optionally ExternalDNS & monitoring. | Vendors upstream OCI chart (`gateway-helm` alias `gatewayprovider`). |
| `external-dns` | Manages DNS records in Google Cloud DNS for Services & Gateway API (HTTPRoute/GRPCRoute). | GCP service account (sealed credentials), Gateway / Services to watch. | Multi‑domain filters, TXT registry, environment isolation. |
| `monitoring` | Prometheus + Thanos components for HA metrics and global aggregation. | `envoy-gateway` (if gRPC exposure), Sealed Secrets, object storage. | Values control Thanos, replicas, routes, TLS. |
| `nginx-ingress-controller` | Traditional NGINX ingress controller for legacy ingress use cases. | None (cluster only). | Prefer Gateway API for new services. |
| `kyverno` | Upstream Kyverno + Policy Reporter + starter ops & security policies (Audit → Enforce). | Sealed Secrets (optional), monitoring (metrics). | Policy groups toggled via `opsPolicies.*` / `secPolicies.*`. |
| `redis` | Vendors upstream Bitnami Redis for cache/session workloads. | Sealed Secrets (auth), monitoring (metrics). | Enable auth & persistence in env overrides before production. |
| `logging` | Centralized multi‑cluster logging (Elasticsearch + Kibana + Filebeat) using ECK operator & mTLS via Gateway. | `envoy-gateway` (ingest endpoint), Sealed Secrets (certs), eck-operator. | Deployed with Helm release name `logging`; ops cluster hosts ES/Kibana; other clusters ship via Filebeat. |

## Environment Overrides
Each chart provides environment value files:
```
values.dev-01.yaml
values.stag-01.yaml
values.ops-01.yaml
values.prod-01.yaml
```
Use the matching file (or merge multiple with `-f`).

## Suggested Install / Bootstrap Order
1. Argo CD (out-of-band)
2. `app-of-apps`
3. `sealed-secrets`
4. `kyverno` (Audit first)
5. `external-dns`
6. `envoy-gateway`
7. `nginx-ingress-controller` (if needed)
8. `monitoring`
9. `logging` (after gateway + secrets ready)
10. `redis` (as needed by apps)

(Order of redis / elastic-stack can swap based on dependency timing.)

## app-of-apps Chart Switches (from `values.yaml` excerpt)
```
sealedSecrets.enable        # sealed-secrets controller + global secrets
ingressController.enable    # nginx ingress controller
envoyGateway.enable         # envoy gateway platform ingress
monitoring.enable           # monitoring stack (Prometheus/Thanos)
kyverno.enable              # kyverno policies + reporter
redis.enable                # redis data service
logging.enable              # elastic logging stack (Helm release name: logging)
```
Each block also supplies:
- `project`: Argo CD Project name
- `namespace`: Target namespace for component
- `source.repoURL` / `path` / `targetRevision`
- Optional Helm release metadata under `helm`

## Cross‑Chart Relationships
- Monitoring gRPC exposure uses Envoy Gateway for external Thanos Query.
- ExternalDNS publishes hosts from Envoy Gateway (Gateway API) & any ingress objects.
- Logging relies on Envoy Gateway for mTLS log ingestion endpoints and Sealed Secrets for TLS cert material.
- Kyverno enforces standards on workloads deployed by other charts (progress Audit→Enforce).
- Redis and Logging Stack may expose metrics scraped by monitoring.
- Sealed Secrets underpins secret distribution for monitoring, external-dns, kyverno (exceptions), redis (auth), elastic-stack (certs/credentials).

## Typical Helm Install (direct)
(Argo CD users normally let Argo reconcile instead of manual installs.)
```bash
# Example: deploy redis into dev
helm dependency update ./redis
helm upgrade --install redis ./redis -f redis/values.dev-01.yaml -n data --create-namespace
```

## Argo CD (GitOps) Flow
1. Commit value/template changes.
2. Argo CD root app detects drift.
3. Child Applications reconcile to desired state.

## DNS & Certificates
- Ensure Cloud DNS zones exist for all `external-dns` domains.
- Seal or externally manage TLS and client certs for Envoy Gateway routes (monitoring & logging gRPC/HTTPS).

## Security Considerations
- Principle of least privilege for service accounts & secrets.
- Rotate sealed secrets periodically.
- Enforce policies with Kyverno only after Audit stabilization.
- Enable Redis auth & persistence before production use.
- Protect Elasticsearch & Kibana with auth + mTLS where applicable.

## Development & Testing
```bash
helm template monitoring ./monitoring -f monitoring/values.dev-01.yaml | less
helm lint monitoring
```

## Contribution Guidelines
- Update per‑chart README on changes.
- Keep inventory table aligned with actual charts.
- Bump chart versions on template/value default changes.

## License
Internal use only unless stated otherwise.
