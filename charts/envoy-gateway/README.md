# envoy-gateway Helm Chart

## Overview
Deploys Envoy Gateway (EG) components and optionally configures a Gateway resource for downstream charts (e.g. monitoring / Thanos gRPC route).

## Features
- Installs Envoy Gateway via dependency (`gatewayprovider` alias)
- Vendors upstream OCI chart `gateway-helm` (Envoy Gateway) so you can layer custom GatewayClasses, Gateways, Routes, security & proxy configs
- Provides base `values.*.yaml` per environment
- Can be extended with security policies and TLS materials

## Upstream Dependency
This chart wraps the official Envoy Gateway Helm chart:
```
dependencies:
  - name: gateway-helm
    alias: gatewayprovider
    version: v1.4.2
    repository: oci://docker.io/envoyproxy
```
All upstream values are set beneath the `gatewayprovider` key in this chart's `values.yaml` / environment overrides. This lets you:
- Keep local opinionated manifests (Gateway, HTTPRoute, GRPCRoute, security policies)
- Override upstream defaults without forking
- Pin the upstream version explicitly for reproducible installs

Update / pull the dependency before packaging or installing directly:
```bash
helm dependency update ./envoy-gateway
```

## Configuration
Edit `values.yaml` or environment overrides. Common keys:
- `gatewayprovider`: Upstream Envoy Gateway chart values (mirrors upstream structure)
- Custom Gateway / Listener / Route definitions may be added under `templates/`

## Deploy
```bash
helm dependency update ./envoy-gateway
helm upgrade --install envoy-gateway ./envoy-gateway -f envoy-gateway/values.dev-01.yaml -n envoy-gateway-system --create-namespace
```

## Prerequisites
- Kubernetes v1.27+
- CRDs installed by Envoy Gateway (fetched & applied automatically by dependency if not present)

## Notes
- Other charts (e.g. monitoring) will reference the Gateway created here
- ExternalDNS can publish hostnames defined by Routes rendered by this chart
