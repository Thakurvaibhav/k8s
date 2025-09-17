# envoy-gateway Helm Chart

## Overview
Deploys Envoy Gateway (EG) components and optionally configures a Gateway resource for downstream charts (e.g. monitoring / Thanos gRPC route).

## Features
- Installs Envoy Gateway via dependency (`gatewayprovider` alias)
- Provides base `values.*.yaml` per environment
- Can be extended with security policies and TLS materials

## Configuration
Edit `values.yaml` or environment overrides. Common keys:
- `gatewayprovider`: Upstream Envoy Gateway chart values
- Custom Gateway / Listener definitions may be added under `templates/`

## Deploy
```bash
helm upgrade --install envoy-gateway ./envoy-gateway -f values.dev-01.yaml -n envoy-gateway-system
```

## Prerequisites
- Kubernetes v1.27+
- CRDs installed by Envoy Gateway (handled automatically by dependency if enabled)

## Notes
- Other charts (e.g. monitoring) will reference the Gateway created here
