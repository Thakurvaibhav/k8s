# Helm Charts

## Platform in a Box
These charts implement a "Platform in a Box"—a batteries‑included, GitOps driven foundation for operating a Kubernetes platform using the Argo CD App‑of‑Apps pattern. They compose the core traffic, security, observability, and enablement layers so teams can onboard applications quickly with consistent guardrails.

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
| `app-of-apps` | Argo CD App‑of‑Apps root that defines Argo CD `Application` objects for platform components (monitoring, ingress, gateway, secrets). | Argo CD CRDs present in cluster. Optionally Sealed Secrets controller if you enable secret management here. | Toggle components via values: `sealedSecrets`, `ingressController`, `envoyGateway`, `monitoring`. Each has `enable` and source repo/path settings. |
| `sealed-secrets` | Vendors upstream Bitnami Sealed Secrets controller and (optionally) renders shared/global sealed secrets. | Installed via `app-of-apps` (if `sealedSecrets.enable=true`). Consumed by charts needing encrypted creds (monitoring, external-dns, others). | Supports user‑defined controller key; global secrets only (app‑specific secrets stay with the app chart). |
| `envoy-gateway` | Deploys Envoy Gateway (Gateway API) plus custom GatewayClasses, Gateways, Routes, security & proxy policies. | Kubernetes >=1.27, optionally ExternalDNS & monitoring. | Vendors upstream OCI chart (`gateway-helm` as alias `gatewayprovider`) allowing pinned upstream with local overlays. |
| `external-dns` | Manages DNS records in Google Cloud DNS for Services & Gateway API (HTTPRoute/GRPCRoute). | GCP service account (sealed credentials), Gateway / Services to watch. | Supports multi‑domain filters, TXT registry, environment isolation via `txtOwner`. |
| `monitoring` | Prometheus + Thanos components for HA metrics and optional global aggregation/gRPC exposure via Envoy Gateway. | (Optional) `envoy-gateway` if exposing Thanos Query externally; object storage creds (sealed); Sealed Secrets controller. | Environment overrides drive Thanos enablement, replica counts, gRPC route exposure & TLS material. |
| `nginx-ingress-controller` | Traditional NGINX ingress controller for legacy/HTTP ingress use cases not on Gateway API. | None (cluster only). May coexist with Envoy Gateway. | Pick either Gateway or Ingress per app path where possible to reduce overlap. |

## Environment Overrides
Each chart provides environment value files:
```
values.dev-01.yaml
values.stag-01.yaml
values.ops-01.yaml
values.prod-01.yaml
```
Use the matching file (or merge multiple with `-f`) when installing or syncing via Argo CD.

## Suggested Install / Bootstrap Order
1. Install Argo CD (outside these charts) – provides `argocd` namespace & CRDs.
2. `app-of-apps` – creates Argo CD `Application` objects (if components enabled).
3. `sealed-secrets` – controller + global secrets (if using sealed secrets) so subsequent charts can decrypt credentials.
4. `external-dns` – so DNS names begin reconciling early (if using Gateway/Ingress hostnames).
5. `envoy-gateway` – provisions Gateway API infra consumed by monitoring (gRPC) or future apps.
6. `nginx-ingress-controller` – only if you need classic Ingress alongside Gateway API.
7. `monitoring` – after routing layer (Envoy or NGINX) is available when external exposure is desired.

(You may reorder `external-dns` and routing controllers depending on credential readiness.)

## app-of-apps Chart Switches (from `values.yaml` excerpt)
```
sealedSecrets.enable        # Installs Sealed Secrets controller (Bitnami chart) if true
ingressController.enable    # Creates Argo CD Application for nginx-ingress-controller
envoyGateway.enable         # Creates Argo CD Application for envoy-gateway
monitoring.enable           # Creates Argo CD Application for monitoring stack
```
Each block also supplies:
- `project`: Argo CD Project name
- `namespace`: Target namespace for component
- `source.repoURL` / `path` / `targetRevision`
- Optional Helm release metadata under `helm`

## Cross‑Chart Relationships
- Monitoring gRPC exposure relies on Envoy Gateway (Gateway + Listener + Route) when `thanos.query.scrape.grpcRoute.enabled` in `monitoring` values.
- ExternalDNS publishes hostnames defined by Gateway HTTP/GRPC Routes (`envoy-gateway`) or standard Ingress objects (`nginx-ingress-controller`).
- Sealed Secrets (if enabled through `app-of-apps` or pre‑installed) is consumed by `monitoring`, `external-dns`, and any future charts needing encrypted credentials.
- Both `envoy-gateway` and `nginx-ingress-controller` can coexist; prefer Gateway API for new traffic patterns.

## Typical Helm Install (direct)
(Argo CD users normally let Argo reconcile instead of manual installs.)
```bash
# Example: deploy envoy-gateway into dev
helm upgrade --install envoy-gateway ./envoy-gateway -f envoy-gateway/values.dev-01.yaml -n envoy-gateway-system --create-namespace
```

## Argo CD (GitOps) Flow
1. Push changes to values / templates.
2. Argo CD root application (from `app-of-apps`) detects drift.
3. Child Applications sync respective charts with correct environment overrides.

## DNS & Certificates
- Ensure GCP Cloud DNS zones exist for all `domainFilters` in `external-dns`.
- Provide sealed service account JSON via `external-dns.values.yaml` (`sealedCredentials`).
- For monitoring gRPC/TLS exposure, seal TLS cert/key + CA before enabling route.

## Security Considerations
- Scope GCP service account to required DNS zones only.
- Rotate sealed secrets when credentials change; commit new encrypted payloads.
- Use network policies to restrict access to Prometheus / Thanos internals; expose only through approved gateways.

## Development & Testing
Render a chart locally:
```bash
helm template monitoring ./monitoring -f monitoring/values.dev-01.yaml | less
```
Lint (if configured):
```bash
helm lint monitoring
```

## Contribution Guidelines
- Update the per‑chart README if adding/removing values or templates.
- Keep this inventory table in sync when adding new charts.
- Prefer additive changes; version bump the chart (`Chart.yaml`) on any template or default value change.

## License
Internal use only unless stated otherwise.
