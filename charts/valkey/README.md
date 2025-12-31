# valkey Helm Chart

## Overview
This chart vendors the upstream Valkey Helm chart and provides a thin wrapper for environment‑specific configuration. Valkey is a fork of Redis focused on high performance, low latency, and modern features. This chart is suitable for caching, session storage, and real-time data processing workloads.

## Upstream Dependency
Declared in `Chart.yaml`:
```
dependencies:
  - name: valkey
    version: 0.9.0
    repository: https://valkey.io/valkey-helm/
```
Pinning the upstream version ensures reproducible deployments and controlled upgrades.

## Features
- Upstream Valkey with replication support (HA mode)
- Environment overrides (`values.dev-01.yaml`, `values.stag-01.yaml`, etc.)
- High availability with replica mode enabled by default
- Persistent storage with custom StorageClass
- Metrics exporter for Prometheus integration
- Pod anti-affinity for distribution across nodes
- Resource limits and requests configured

**Note:** The current version of the Valkey chart supports replication mode for high availability. Sentinel mode support is coming soon and will provide additional failover capabilities.

## Configuration

### Key Values

| Key | Purpose | Default |
|-----|---------|---------|
| `valkey.replica.enabled` | Enable HA with replicas | `true` |
| `valkey.replica.replicas` | Number of replica instances | `2` |
| `valkey.replica.minReplicasToWrite` | Minimum replicas required for writes | `1` |
| `valkey.replica.persistence.enabled` | Enable persistent storage | `true` |
| `valkey.replica.persistence.size` | Storage size per instance | `100Gi` |
| `valkey.replica.persistence.storageClass` | StorageClass name | `valkey` |
| `valkey.metrics.enabled` | Enable Prometheus metrics exporter | `true` |
| `valkey.resources` | CPU/memory requests and limits | See values.yaml |
| `storageClass.provisioner` | StorageClass provisioner | Update per environment |

### StorageClass

The chart includes a custom StorageClass template (`templates/storageClass.yaml`) that must be configured per environment. Update `storageClass.provisioner` in environment-specific values files to match your cluster's storage provisioner (e.g., `kubernetes.io/gce-pd`, `ebs.csi.aws.com`, `disk.csi.azure.com`).

Example for GCP:
```yaml
storageClass:
  provisioner: pd.csi.storage.gke.io
  parameters:
    type: pd-ssd
```

## Deployment

### GitOps (Recommended)
In GitOps flow, the `app-of-apps` chart toggles inclusion via `valkey.enable: true` in the environment values.

### Direct Helm Install
```bash
helm dependency update ./valkey
helm upgrade --install valkey ./valkey -f valkey/values.dev-01.yaml -n data --create-namespace
```

## High Availability

The chart is configured for HA by default:
- **Replica mode**: Enabled with 2 replicas (currently supported)
- **Min replicas to write**: 1 (allows writes even if one replica is down)
- **Pod anti-affinity**: Ensures replicas are distributed across different nodes
- **Persistence**: Enabled to preserve data across pod restarts
- **Sentinel mode**: Coming soon - will provide automatic failover and monitoring

For production environments, consider:
- Increasing replica count for higher availability
- Adjusting `minReplicasToWrite` based on your consistency requirements
- Configuring backup strategies for persistent volumes
- Monitoring for Sentinel mode availability for enhanced failover capabilities

## Metrics & Monitoring

Metrics exporter is enabled by default and exposes Prometheus-compatible metrics:
- Service annotations include `prometheus.io/scrape: "true"` for auto-discovery
- Metrics endpoint available on the metrics service
- Integrates with the platform's monitoring stack (Prometheus/Thanos)

## Resource Management

Default resource configuration:
- **Limits**: 1200m CPU, 6Gi memory
- **Requests**: 900m CPU, 512Mi memory
- **Init resources**: 100m CPU, 128Mi memory

Adjust these values in environment-specific overrides based on:
- Expected workload and traffic patterns
- Cluster node sizes and capacity
- Performance requirements

## Security Considerations

- **Network policies**: Consider adding NetworkPolicies to restrict access to only namespaces/workloads needing Valkey
- **TLS**: Enable TLS in transit if required (configure via upstream chart values)
- **Authentication**: Configure authentication if needed (not enabled by default)
- **RBAC**: Ensure service accounts have appropriate permissions

## Operational Notes

- **Persistence**: Enabled by default - ensure StorageClass is properly configured per environment
- **Backups**: Implement backup strategies for persistent volumes containing critical data
- **Scaling**: Adjust replica count based on load and availability requirements
- **Upgrades**: Test upgrades in lower environments before promoting to production

## Scaling

To scale Valkey:
1. Update `valkey.replica.replicas` in environment values file
2. Ensure cluster has sufficient node capacity
3. Monitor resource usage and performance after scaling

## Upgrades

1. Review upstream release notes for breaking changes
2. Bump dependency version in `Chart.yaml`
3. Run `helm dependency update ./valkey`
4. Test in lower environment before promoting
5. Monitor metrics and logs during upgrade

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| Pods not starting | StorageClass not configured | Update `storageClass.provisioner` in values |
| High memory usage | Insufficient resources | Increase memory limits/requests |
| Write failures | Not enough replicas | Check `minReplicasToWrite` setting |
| Metrics not scraping | Service annotations missing | Verify `prometheus.io/scrape` annotation |

## Adding Platform Customizations

Add new templates under `templates/` (e.g., NetworkPolicy, ServiceMonitor) guarded by values flags to keep the base chart lean.

## License
Internal use unless otherwise specified.

