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
| `app-of-apps` | Argo CD App‑of‑Apps root that defines Argo CD `Application` objects for platform components (monitoring, ingress, gateway, secrets, policies, data services, logging). | Argo CD CRDs present in cluster. Optionally Sealed Secrets controller if you enable secret management here. | Toggle components via values: `sealedSecrets`, `ingressController`, `envoyGateway`, `externalDns`, `certManager`, `monitoring`, `kyverno`, `redis`, `logging`, `jaeger`. |
| `sealed-secrets` | Vendors upstream Bitnami Sealed Secrets controller and (optionally) renders shared/global sealed secrets. | Installed via `app-of-apps` (if `sealedSecrets.enable=true`). Consumed by charts needing encrypted creds (monitoring, external-dns, others). | Supports user‑defined controller key; global secrets only. |
| `cert-manager` | Issues TLS certs via ACME (DNS‑01 GCP Cloud DNS example) and reflects cert Secrets cluster‑wide using reflector. | Sealed Secrets (for DNS svc acct), ExternalDNS (aligned DNS zones), consumers: envoy-gateway, logging, jaeger, ingress. | Upstream `cert-manager` + `reflector`; wildcard cert reuse via annotations. |
| `envoy-gateway` | Deploys Envoy Gateway (Gateway API) plus custom GatewayClasses, Gateways, Routes, security & proxy policies. | Kubernetes >=1.27, optionally ExternalDNS & monitoring. | Vendors upstream OCI chart (`gateway-helm` alias `gatewayprovider`). |
| `external-dns` | Manages DNS records in Google Cloud DNS for Services & Gateway API (HTTPRoute/GRPCRoute). | GCP service account (sealed credentials), Gateway / Services to watch. | Multi‑domain filters, TXT registry, environment isolation. |
| `monitoring` | Prometheus + Thanos components for HA metrics and global aggregation. | `envoy-gateway` (if gRPC exposure), Sealed Secrets, object storage. | Values control Thanos, replicas, routes, TLS. |
| `nginx-ingress-controller` | Traditional NGINX ingress controller for legacy ingress use cases. | None (cluster only). | Prefer Gateway API for new services. |
| `kyverno` | Upstream Kyverno + Policy Reporter + starter ops & security policies (Audit → Enforce). | Sealed Secrets (optional), monitoring (metrics). | Policy groups toggled via `opsPolicies.*` / `secPolicies.*`. |
| `redis` | Vendors upstream Bitnami Redis for cache/session workloads. | Sealed Secrets (auth), monitoring (metrics). | Enable auth & persistence in env overrides before production. |
| `logging` | Centralized multi‑cluster logging (Elasticsearch + Kibana + Filebeat) using ECK operator & mTLS via Gateway. | `envoy-gateway` (ingest endpoint), Sealed Secrets (certs), eck-operator. | Deployed with Helm release name `logging`; ops cluster hosts ES/Kibana; other clusters ship via Filebeat. |
| `jaeger` | Multi‑cluster tracing (collectors in all clusters, query UI only in Ops) storing spans in shared Elasticsearch (logging stack). | `logging` (Elasticsearch), Sealed Secrets (ES creds / TLS), optional Envoy Gateway (if exposing query). | Agents optional (apps can emit OTLP direct); uses upstream Jaeger chart. |

## Component Categories
| Category | Purpose / Scope | Components | Recommendation / Notes |
|----------|-----------------|------------|------------------------|
| GitOps Orchestration | Declarative deployment & synchronization of all platform layers | `app-of-apps` (Argo CD root) | Keep lean; only owns Argo CD Application CRs. |
| Traffic Management & Routing | North/South & East/West HTTP/gRPC ingress, routing, DNS publishing | `envoy-gateway`, `external-dns`, `nginx-ingress-controller` | Prefer Gateway API via `envoy-gateway`; `nginx-ingress-controller` legacy only. |
| Secrets Management | Encrypted distribution of sensitive config & cert/key material | `sealed-secrets` | Rotate controller key; treat sealed manifests as immutable. |
| Compliance & Policy | Admission controls, governance, workload standards (Audit→Enforce) | `kyverno` | Start Audit, promote critical policies to Enforce gradually. |
| TLS & Certificates | Automated ACME issuance, renewal, wildcard/SAN cert reuse across namespaces | `cert-manager`, `reflector` | Use DNS-01 (GCP Cloud DNS) for wildcards; reflect only ingress/public certs; future: add additional issuers. |
| Observability: Metrics | Cluster & app metrics, long-term aggregation | `monitoring` (Prometheus + Thanos) | Enable Thanos for multi-cluster federation. |
| Observability: Logs | Centralized log storage & search | `logging` (Elasticsearch + Kibana + Filebeat) | mTLS ingest; size ES per retention & volume. |
| Observability: Tracing | Distributed trace collection & visualization | `jaeger` (collectors everywhere, query in Ops) | Agents optional; spans stored in Logging ES. |
| Data Services (Shared) | Shared infra data services for apps / platform features | `redis` | Enable auth & persistence before production. |

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
10. `jaeger` (after logging / ES available)
11. `redis` (as needed by apps)

(Order of redis / jaeger can swap if trace storage readiness precedes need for Redis.)

## app-of-apps Chart Switches (from `values.yaml` excerpt)
```
sealedSecrets.enable        # sealed-secrets controller + global secrets
certManager.enable          # cert-manager + reflector for certificate issuance
externalDns.enable          # external-dns controller for DNS records
ingressController.enable    # nginx ingress controller
envoyGateway.enable         # envoy gateway platform ingress
monitoring.enable           # monitoring stack (Prometheus/Thanos)
kyverno.enable              # kyverno policies + reporter
redis.enable                # redis data service
logging.enable              # elastic logging stack (Helm release name: logging)
jaeger.enable               # distributed tracing (Jaeger collectors + optional query UI)
```
Each block also supplies:
- `project`: Argo CD Project name
- `namespace`: Target namespace for component
- `source.repoURL` / `path` / `targetRevision`
- Optional Helm release metadata under `helm`

## Cross‑Chart Relationships
- Monitoring gRPC exposure uses Envoy Gateway for external Thanos Query.
- ExternalDNS publishes hosts from Envoy Gateway (Gateway API) & any ingress objects.
- Cert-Manager issues wildcard / SAN certs consumed by Envoy Gateway, logging (Kibana/ES ingress), Jaeger Query, and any legacy ingress objects; reflector replicates cert secrets.
- Logging relies on Envoy Gateway for mTLS log ingestion endpoints and Sealed Secrets for TLS cert material.
- Jaeger collectors write spans to Elasticsearch in the logging stack; Query UI only runs in Ops cluster; optional exposure via Envoy Gateway / ingress.
- Jaeger agents are optional when applications can emit OTLP directly to collector services.
- Kyverno enforces standards on workloads deployed by other charts (progress Audit→Enforce).
- Redis, Logging Stack, and Jaeger may expose metrics scraped by monitoring.
- Sealed Secrets underpins secret distribution (monitoring, external-dns, kyverno, redis, logging, jaeger, cert-manager DNS creds).

## DNS & Certificates
- Ensure Cloud DNS zones exist for all `external-dns` domains.
- Cert-Manager handles ACME issuance (DNS-01) and reflector replicates certificate secrets where needed.
- Seal or externally manage TLS and client certs for specialized mTLS (e.g., logging ingest) separate from public certs.

## Security Considerations
- Principle of least privilege for service accounts & secrets.
- Rotate sealed secrets periodically.
- Enforce policies with Kyverno only after Audit stabilization.
- Enable Redis auth & persistence before production use.
- Protect Elasticsearch & Kibana with auth + mTLS where applicable.
- Secure Jaeger Query with OAuth / SSO and TLS; ensure collectors use mTLS to ES.

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
