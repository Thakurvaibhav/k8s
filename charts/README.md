# Helm Charts Collection

This directory contains organizational Helm charts used across environments (dev, stag, ops, prod).

## Charts
- `app-of-apps`: Argo CD bootstrap (App of Apps) pattern aggregating other applications; can optionally deploy the Bitnami Sealed Secrets controller from the upstream chart. It is recommended to rotate / provide your own controller private key rather than relying on an auto-generated one.
- `envoy-gateway`: Installs and configures Envoy Gateway; provides Gateway resources consumed by other charts.
- `monitoring`: Deploys monitoring stack components (Prometheus/Thanos/etc.) with optional gRPC exposure via Envoy Gateway and mTLS.
- `external-dns`: Manages DNS records in Cloud DNS (Google) for Services and Gateway API routes (HTTP/gRPC) using ExternalDNS.
- `nginx-ingress-controller`: Provides NGINX Ingress Controller installation and configuration.

## Environments
Each chart supports overrides through files named:
- `values.dev-01.yaml`
- `values.stag-01.yaml`
- `values.ops-01.yaml`
- `values.prod-01.yaml`

Apply with:
```bash
helm upgrade --install <release> ./<chart> -f <chart>/values.<env>.yaml -n <namespace>
```

## Common Prerequisites
- Argo CD installed (required for `app-of-apps` workflow)
- Kubernetes cluster (v1.25+ recommended)
- Helm 3
- (Optional) Bitnami Sealed Secrets controller (if not managed by `app-of-apps`); if deployed via `app-of-apps`, supply/restore your own controller key for stable secret re-encryption behavior

## Order of Installation (suggested)
1. `app-of-apps` (bootstraps Sealed Secrets controller and other core apps if configured)
2. `envoy-gateway` (if using Gateway API for gRPC/HTTP routing)
3. `external-dns` (so DNS records appear early for endpoints)
4. `monitoring`
5. `nginx-ingress-controller` (if needed for traditional ingress)

## DNS & Certificates
- Ensure DNS A/AAAA records point to the provisioned LoadBalancer IP(s) or Gateway addresses.
- For mTLS / TLS secrets in `monitoring`, update encrypted values before deploy.

## Conventions
- Keep README in each chart up to date with new templates or values

## Development
Render templates locally:
```bash
helm template monitoring ./monitoring -f monitoring/values.dev-01.yaml | less
```

Lint (if chart-testing or helm lint pipeline is configured):
```bash
helm lint monitoring
```

## Contribution
1. Branch + PR
2. Update README if behavior changes

## License
Internal use only unless stated otherwise.
