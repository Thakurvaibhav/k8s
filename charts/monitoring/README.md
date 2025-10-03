# monitoring Helm Chart

## Overview
The `monitoring` chart deploys a highly available Prometheus stack integrated with Thanos for global, long‑term, and cost‑efficient metrics storage. Multiple cluster Prometheus pairs (replicas) ship metrics to object storage via the Thanos sidecar. Thanos Query layers unify data into ONE Single Pane of Glass for all environments (Dev, Stage, Prod, Ops) through a central Grafana in the ops cluster.

> Single Pane of Glass: Grafana (Ops) + Global Thanos Query aggregate real‑time and historical metrics seamlessly across Dev, Stage, Prod, and Ops clusters over secure mTLS.

## Features
- HA Prometheus (replicas for resilience & zero-ish scrape gap failover)
- Thanos Sidecar for each Prometheus to ship & expose TSDB blocks
- Global aggregation via Thanos Query (single pane of glass)
- Optional Thanos Store / Compactor / Ruler components (if enabled in values)
- Long‑term & durable retention in GCS (object storage)
- Central Grafana (external to this chart) consumes unified Thanos endpoint
- Optional gRPC exposure of Thanos Query through Gateway API (Envoy Gateway) with mTLS
- SealedSecrets for secure delivery of TLS certs & GCS bucket credentials
- Environment specific values overrides (`values.dev-01.yaml`, `values.stag-01.yaml`, etc.)
- Custom resource state metrics (Gateway API CRDs enabled now; extensible to additional CRDs via kube-state-metrics / custom exporters)
- Blackbox exporter for synthetic uptime / reachability probes (annotate Services / Ingress for auto-discovery; Gateway API requires annotating backing Services)

## Important Templates
- `templates/thanos/` (e.g. `thanos-query-route.yaml`): Routing, TLS & mTLS policy (only rendered when enabled)
- Additional Prometheus / Thanos component manifests (refer to chart templates directory)

## High-Level Architecture
```mermaid
graph LR
  %% Dev / Prod / Stage clusters each run full local stack
  subgraph Dev[Dev Cluster]
    PDv[(Prometheus Dev)] --> SDv[Sidecar Dev]
    SDv --> BDv[(GCS Bucket Dev)]
    CDv[Compactor Dev] --> BDv
    SGDv[Store GW Dev] --> BDv
    QDv[Local Query Dev] --> SGDv
    QDv --> SDv
  end
  subgraph Prod[Prod Cluster]
    PPr[(Prometheus Prod)] --> SPr[Sidecar Prod]
    SPr --> BPr[(GCS Bucket Prod)]
    CPr[Compactor Prod] --> BPr
    SGPr[Store GW Prod] --> BPr
    QPr[Local Query Prod] --> SGPr
    QPr --> SPr
  end
  subgraph Stage[Stage Cluster]
    PSt[(Prometheus Stage)] --> SSt[Sidecar Stage]
    SSt --> BSt[(GCS Bucket Stage)]
    CSt[Compactor Stage] --> BSt
    SGSt[Store GW Stage] --> BSt
    QSt[Local Query Stage] --> SGSt
    QSt --> SSt
  end

  %% Ops / Aggregation cluster
  subgraph Ops[Ops Cluster]
    PO[(Prometheus Ops)] --> SO[Sidecar Ops]
    SO --> BO[(GCS Bucket Ops)]
    CO[Compactor Ops] --> BO
    SGO[Store GW Ops] --> BO
    QO[Local Query Ops] --> SGO
    QO --> SO
    GF[Grafana] --> QG[Global Thanos Query]
  end

  %% mTLS federation ONLY to local queries
  QG -. mTLS StoreAPI .-> QDv
  QG -. mTLS StoreAPI .-> QPr
  QG -. mTLS StoreAPI .-> QSt
  QG -. mTLS StoreAPI .-> QO
```

**Legend**
- Local Query (Dev/Stage/Prod/Ops) fans out to in-cluster Sidecar (live) + Store Gateway (historical) + Bucket (indirect via Store GW / Compactor).
- Global Query (QG) connects ONLY to Local Query instances (secure mTLS StoreAPI), forming the aggregate view.
- Grafana queries Global Query to achieve the single pane of glass.

## Single Pane of Glass Benefits
- Unified dashboards across environments without cross-cluster direct Prometheus scraping.
- Consistent RBAC & mTLS boundaries (only Local Query endpoints exposed to Global Query).
- Simplified retention & cost management with per-cluster buckets + global visibility.

## Configuration
Key values:
- `prometheus.replicaCount`: Number of Prometheus replicas per cluster
- `thanos.enabled`: Master switch for Thanos integration
- `thanos.objectStorage.secretRef`: Secret or SealedSecret containing GCS credentials
- `thanos.query.enabled`: Deploy Thanos Query
- `thanos.query.scrape.grpcRoute.enabled`: Expose Query via Gateway API (optional)
- `thanos.query.scrape.grpcRoute.host`: FQDN for external gRPC access
- `thanos.query.scrape.grpcRoute.gatewayName` / `listenerName`: Gateway references
- `thanos.query.scrape.grpcRoute.tlsCrt` / `tlsKey` / `caCrt`: Encrypted (SealedSecret) TLS & client CA data for mTLS

## Example values override (excerpt)
```yaml
prometheus:
  replicaCount: 2
thanos:
  enabled: true
  objectStorage:
    secretRef: thanos-gcs-credentials  # created via SealedSecret
  query:
    enabled: true
    scrape:
      grpcRoute:
        enabled: true            # optional external access
        gatewayName: envoy-public
        listenerName: grpc
        host: thanos-query.example.com
        tlsCrt: <encrypted>
        tlsKey: <encrypted>
        caCrt: <encrypted>
```

## Deploy
```bash
helm upgrade --install monitoring ./monitoring -f values.dev-01.yaml -n monitoring
```

## Operational Notes
- Scale Prometheus via `replicaCount` to achieve HA; use anti-affinity for node spread
- Ensure object storage (GCS bucket) lifecycle policies align with retention goals
- Run Compactor (if enabled) in only one authoritative environment to avoid overlap
- Secure gRPC / HTTP endpoints with mTLS & network policy where possible

## Notes
- Ensure Sealed Secrets controller is installed
- Ensure Envoy Gateway and referenced Gateway exist before applying (if gRPC route enabled)
- Host must have DNS A/AAAA record to Gateway LB IP (when exposing Thanos Query)
- Add SealedSecrets for: (1) GCS bucket service account JSON (Thanos object storage) and (2) TLS certs / client CA used for gRPC/mTLS before enabling corresponding features
- Rotate TLS and storage credentials regularly; updating SealedSecret triggers rolling reloads where applicable

## Custom Resource Metrics (Gateway API & Extensible CRDs)
The chart exposes Gateway API resource state metrics (e.g. Gateways, HTTPRoutes) so you can alert on config drift, readiness, and reconciliation errors. Additional Kubernetes Custom Resource metrics are enabled centrally by editing:

`configs/kube-state-customresource/custom-resource.yaml`

This file declares the extra CRDs kube-state-metrics should watch. Adding a CRD here (group, version, kind) and redeploying the chart causes kube-state-metrics to emit per‑object gauges without writing custom exporters.

## Endpoint Uptime Monitoring (Blackbox Exporter)
This chart enables the Prometheus Blackbox Exporter to perform synthetic probes (HTTP/HTTPS, TCP, TLS) against annotated targets.

### Auto-Discovery
Prometheus automatically discovers and scrapes annotated **Service** and **Ingress** objects. Add standardized annotations so the blackbox exporter generates probe targets:

Example (Service):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-api
  annotations:
    blackbox.io/scheme: https         # http|https
    blackbox.io/path: /healthz        # optional override
    blackbox.io/module: http_2xx      # blackbox exporter module name
spec:
  selector:
    app: my-api
  ports:
    - name: http
      port: 80
```
Example (Ingress):
```yaml
metadata:
  annotations:
    blackbox.io/scheme: https
```

### Gateway API Limitation
Prometheus does not natively service-discover Gateway API `Gateway` / `HTTPRoute` objects for blackbox probing. To monitor Gateway-exposed endpoints:
1. Ensure the backend **Service** representing the entrypoint (or a dedicated “probe” Service) carries the probe annotations.
2. (Optional) Expose a lightweight readiness/health path on that Service that exercises the full routing stack.
3. Use labels (`service`, `gateway_class`, `cluster`, `environment`) so dashboards & alerts can group by gateway context.

### Recommendations
- Probe only critical external paths (health, readiness, public API landing) to minimize noise & cost.
- Prefer explicit `probe-path` to avoid hitting heavy/root pages.
- Use distinct modules (e.g. `http_2xx`, `http_ssl`, `tcp_connect`) for different expectations; alert thresholds can vary per module.
- Tag probes with `environment` & `cluster` via relabeling so cross-cluster SLO dashboards aggregate cleanly.
