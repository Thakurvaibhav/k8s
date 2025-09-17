# external-dns Helm Chart

## Overview
Deploys ExternalDNS to manage DNS records in Google Cloud DNS for Kubernetes resources (Services, HTTPRoutes, GRPCRoutes) across specified domains. Supports environment-specific values and TXT registry ownership isolation.

## Features
- Google Cloud DNS provider
- Multiple domain filters (segments: root, dev, staging, ops)
- Sources: Service, Gateway HTTPRoute, Gateway GRPCRoute
- TXT registry with custom owner ID for safe multi-cluster coexistence
- Optional dry-run mode
- Upsert-only policy (prevents record deletions when enabled)
- Pluggable TXT prefix per Kubernetes provider (EKS/AKS conditional example)

## Values
Key configurable values (see `values.yaml`):
- `namespace`: Namespace to deploy ExternalDNS
- `image.repository` / `image.tag`: Container image
- `logLevel`: Logging verbosity (`info`, `debug`)
- `dryRun`: If true, no changes are pushed
- `upsertOnly`: Only create/update records
- `kubernetesProvider`: Cluster platform hint (adjusts TXT prefix for AWS/Azure examples)
- `dnsConfig.domainFilters[]`: Domains ExternalDNS will manage
- `dnsConfig.sources[]`: Resource sources (e.g., `service`, `gateway-httproute`, `gateway-grpcroute`)
- `dnsConfig.gcpProject`: Target GCP project for Cloud DNS
- `dnsConfig.txtOwner`: TXT registry owner identifier
- `resources`: CPU/memory requests & limits
- (Expected) `credentials.sealedSecret`: Encrypted (Bitnami Sealed Secrets) JSON service account payload referenced by the deployment
- `sealedCredentials`: Base64 (sealed) payload for `external-dns-credentials.json` (shortcut if you do not supply a full SealedSecret manifest)

## Credentials (SealedSecret Delivery)
Populate the `sealedCredentials` value with the sealed (encrypted) JSON for the service account; the chart will render a SealedSecret named `external-dns-credentials` with key `external-dns-credentials.json`.

## Example Install
```bash
helm upgrade --install external-dns ./external-dns \
  -f external-dns/values.dev-01.yaml \
  -n external-dns --create-namespace
```

## Upsert-Only vs Full Sync
- `upsertOnly: true` prevents deletions (safer initial posture)
- Set to `false` to allow pruning of stale records

## Dry Run
Enable `dryRun: true` to observe intended changes without applying them.

## Domain Strategy
Use focused `domainFilters` to scope reconciliation and reduce API calls. Include only the zones the service account is permitted to modify.

## TXT Ownership
The TXT registry prevents record conflicts. Use distinct `txtOwner` per environment if sharing zones.

## Gateway API Sources
Ensure the Gateway controller populates status addresses so ExternalDNS can publish A/AAAA records for routes.

## Resource Tuning
Adjust `resources` per cluster scale. Monitor controller latency & Cloud DNS API quotas.

## Security
- Scope service account to required managed zones
- Prefer SealedSecret delivery over ad-hoc `kubectl` secret creation for GitOps
- Consider `--policy=sync` only after validating no destructive changes
- Run with least privilege and network policies if applicable

## License
Internal use only unless stated otherwise.
