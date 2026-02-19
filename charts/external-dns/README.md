# external-dns Helm Chart

## Overview
This chart vendors the upstream ExternalDNS Helm chart and provides a thin wrapper for environment-specific configuration. ExternalDNS automatically manages DNS records in Google Cloud DNS for Kubernetes resources (Services, HTTPRoutes, GRPCRoutes) across specified domains. It supports TXT registry ownership isolation for safe multi-cluster coexistence.

## Upstream Dependency
Declared in `Chart.yaml`:
```
dependencies:
  - name: external-dns
    version: 1.20.0
    repository: https://kubernetes-sigs.github.io/external-dns/
```
Pinning the upstream version ensures reproducible deployments and controlled upgrades.

## Features
- Google Cloud DNS provider integration
- Multiple domain filters (segments: root, dev, staging, ops)
- Sources: Service, Gateway HTTPRoute, Gateway GRPCRoute
- TXT registry with custom owner ID for safe multi-cluster coexistence
- Optional dry-run mode for safe testing
- Upsert-only policy (prevents record deletions when enabled)
- Environment-specific values files (`values.dev-01.yaml`, `values.stag-01.yaml`, etc.)
- Sealed Secrets integration for secure credential delivery

## Configuration

### Key Values

| Key | Purpose | Default |
|-----|---------|---------|
| `namespace` | Namespace to deploy ExternalDNS | `external-dns` |
| `external-dns.logLevel` | Logging verbosity (`info`, `debug`) | `info` |
| `external-dns.logFormat` | Log format (`text`, `json`) | `json` |
| `external-dns.interval` | Sync interval | `5m` |
| `external-dns.provider` | DNS provider | `google` |
| `external-dns.sources` | Resource sources to watch | `[service, gateway-httproute, gateway-grpcroute]` |
| `external-dns.domainFilters` | Domains ExternalDNS will manage | Set per environment |
| `external-dns.extraArgs` | Additional command-line arguments | `[--google-project, --registry=txt, --txt-owner-id]` |
| `external-dns.resources` | CPU/memory requests and limits | See values.yaml |
| `kubernetesProvider` | Cluster platform hint (adjusts TXT prefix) | `GKE` |
| `sealedCredentials` | Base64 sealed payload for service account JSON | `""` |

### Environment-Specific Configuration
Each environment has its own values file:
- `values.dev-01.yaml`: Development cluster configuration
- `values.stag-01.yaml`: Staging cluster configuration
- `values.prod-01.yaml`: Production cluster configuration
- `values.ops-01.yaml`: Operations cluster configuration

Each file configures:
- `domainFilters`: Environment-specific domains to manage
- `extraArgs`: GCP project and TXT owner ID for isolation

## Credentials (SealedSecret Delivery)

The chart expects GCP service account credentials to be provided via Sealed Secrets. Populate the `sealedCredentials` value with the sealed (encrypted) JSON for the service account; the chart will render a SealedSecret named `external-dns-credentials` with key `external-dns-credentials.json`.

The service account must have permissions to:
- Read and write DNS records in the target Cloud DNS zones
- Create TXT records for ownership tracking

**Security Note**: Scope the service account permissions to only the required managed zones. Never grant broader DNS permissions than necessary.

## Deployment

### GitOps (Recommended)
In GitOps flow, the `app-of-apps` chart toggles inclusion via `externalDNS.enable: true` in the environment values. ExternalDNS is deployed as part of the traffic management stack with proper sync wave ordering (after `sealed-secrets` and `cert-manager`).

### Direct Helm Install
```bash
helm dependency update ./external-dns
helm upgrade --install external-dns ./external-dns \
  -f external-dns/values.dev-01.yaml \
  -n external-dns --create-namespace
```

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| DNS records not created | Missing or invalid credentials | Verify SealedSecret is unsealed and service account has permissions |
| Records not updating | Wrong domain filter | Check `domainFilters` match target zones |
| TXT conflicts | Duplicate owner ID | Use unique `txtOwner` per environment/cluster |
| High API usage | Too many domain filters | Narrow `domainFilters` to required zones only |
| Gateway routes not discovered | Gateway status not populated | Verify Gateway controller is working and status addresses are set |
| Dry-run shows no changes | Sources not configured | Check `sources` list includes expected resource types |

## Integration with Other Components

- **Envoy Gateway**: ExternalDNS publishes hostnames from Gateway API routes (HTTPRoute, GRPCRoute) created by Envoy Gateway
- **cert-manager**: Both use the same Cloud DNS zones; ensure service accounts have appropriate permissions
- **Sealed Secrets**: Credentials are delivered via Sealed Secrets for GitOps compliance

## Resource Tuning
Adjust `resources` per cluster scale. Monitor controller latency & Cloud DNS API quotas.

## License
Internal use only unless stated otherwise.
