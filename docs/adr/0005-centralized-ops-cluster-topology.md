# ADR-005: Centralized Ops Cluster Topology

## Status
Accepted

## Context

I needed to design a multi-cluster Kubernetes architecture that supports:

- **Multiple environments**: Dev, staging, production clusters
- **Centralized control**: Single point of management for all clusters
- **Observability aggregation**: Unified view of metrics, logs, and traces across clusters
- **GitOps orchestration**: Centralized Argo CD managing all clusters
- **Security isolation**: Environments isolated but manageable from central location
- **Operational efficiency**: Minimize operational overhead while maintaining control
- **Cost optimization**: Avoid duplicating expensive observability backends in each cluster

Common multi-cluster patterns have trade-offs:
- **Federated control planes**: Each cluster has its own Argo CD (operational overhead, no unified view)
- **Hub-and-spoke**: Central hub manages spokes (good for control, but hub is SPOF)
- **Peer-to-peer**: Clusters manage each other (complex, no clear ownership)
- **Regional clusters**: Geographic distribution (adds latency, complexity)

## Decision

I adopted a **centralized Ops cluster topology** where:

**Ops Cluster (Central Command & Control):**
- Hosts Argo CD control plane (API server, repo server, application controller)
- Runs centralized observability backends:
  - Thanos Query (global metrics aggregation)
  - Grafana (unified dashboards)
  - Elasticsearch/Kibana (centralized logging)
  - Jaeger Query UI (distributed tracing)
- Provides single RBAC and audit surface
- Exposes minimal northbound endpoints (UI, API, metrics)
- Manages its own platform components (via App-of-Apps)

**Workload Clusters (Dev, Staging, Prod):**
- **Execution targets only**: No Argo CD control plane (managed remotely)
- **Local components**: Envoy Gateway, Kyverno, Prometheus (for local collection)
- **Telemetry agents**: Filebeat, Prometheus, Jaeger collectors (ship to Ops)
- **Outbound connectivity**: Connect to Ops cluster for GitOps and observability
- **No inbound access**: Clusters don't need to accept connections from each other

**Key Principles:**
1. **Ops cluster = authoritative source**: All deployment decisions originate here
2. **Workload clusters = execution targets**: They run workloads, not control planes
3. **Unidirectional flow**: Ops → Workload clusters (GitOps reconciliation)
4. **Telemetry flows back**: Metrics/logs/traces flow from workloads → Ops
5. **Local enforcement**: Policy (Kyverno) and ingress (Envoy Gateway) run locally for low latency

## Consequences

### Positive

- **Single source of truth**: One Argo CD UI shows all clusters and applications
- **Unified observability**: One Grafana/Kibana/Jaeger for all clusters
- **Centralized RBAC**: Control who can promote to production from one place
- **Cost efficiency**: Expensive backends (ES, Thanos) only in Ops cluster
- **Operational simplicity**: One control plane to operate, monitor, and backup
- **Clear ownership**: Centralized control plane, workload clusters are execution targets
- **Audit trail**: All changes visible in single Argo CD event log
- **Easier troubleshooting**: Centralized logs and metrics for all clusters
- **Promotion workflow**: Git-driven (dev → staging → stable) managed centrally
- **Security**: Workload clusters have minimal attack surface (no control plane)

### Negative

- **Single point of failure**: Ops cluster outage pauses reconciliation (though workloads keep running)
- **Network dependency**: Workload clusters must reach Ops cluster (outbound)
- **Latency**: Argo CD API calls go to Ops cluster (acceptable for GitOps, not user-facing)
- **Ops cluster scale**: Must handle load from all clusters (scalable with proper sizing)
- **Disaster recovery**: Ops cluster failure requires recovery procedure
- **Network requirements**: Outbound connectivity from all clusters to Ops
- **Initial complexity**: More complex than single-cluster setup

### Mitigations

- **Resilience**: Ops cluster runs in HA mode (multiple replicas, persistent storage)
- **Workload continuity**: Existing workloads continue running during Ops outage (only reconciliation pauses)
- **Recovery procedures**: Documented disaster recovery runbooks
- **Monitoring**: Comprehensive monitoring of Ops cluster health
- **Backup**: Regular backups of Argo CD state and observability data
- **Network design**: VPN/private connectivity between clusters for security

## Alternatives Considered

### 1. Federated Control Planes (Argo CD in Each Cluster)
**Rejected because:**
- Operational overhead (manage Argo CD in 5+ clusters)
- No unified view (must check each cluster separately)
- Inconsistent configurations (drift risk)
- Higher resource costs (Argo CD in every cluster)
- Difficult to coordinate promotions across clusters

### 2. Regional Ops Clusters (Multiple Ops Clusters)
**Rejected because:**
- More complex (multiple control planes to operate)
- Coordination challenges (which Ops cluster manages which workloads?)
- Higher costs (multiple observability backends)
- Only needed if regulatory/geographic isolation required
- Can be added later if needed (see Multi-Ops Variant in README)

### 3. Managed Argo CD (Argo CD SaaS)
**Rejected because:**
- Vendor lock-in
- Data sovereignty concerns (GitOps state in external system)
- Less control over configuration
- Cost at scale
- I want to keep everything GitOps-managed and self-hosted

### 4. GitOps Tool per Cluster (Flux, Argo CD, etc.)
**Rejected because:**
- Tool sprawl (different tools in different clusters)
- No unified management
- Inconsistent patterns
- Higher learning curve (must know multiple tools)

### 5. No Centralized Control (Manual kubectl)
**Rejected because:**
- Not GitOps (no declarative desired state)
- Error-prone (manual operations)
- No audit trail
- Doesn't scale to many clusters
- Inconsistent configurations

## Implementation Details

**Argo CD Configuration:**
- Ops cluster: Full Argo CD installation (API, repo-server, application-controller)
- Workload clusters: Registered as remote clusters (cluster secrets in Argo CD)
- Applications: Target remote clusters via `destination.cluster` field
- Naming: Applications named `<cluster>-<component>` for clarity

**Observability Flow:**
- **Metrics**: Prometheus (each cluster) → Thanos Sidecar → Object Storage → Thanos Query (Ops)
- **Logs**: Filebeat (each cluster) → Envoy Gateway (Ops) → Elasticsearch (Ops)
- **Traces**: Jaeger Collectors (each cluster) → Elasticsearch (Ops) → Jaeger Query (Ops)

**Network Requirements:**
- Workload clusters: Outbound to Ops cluster (Argo CD API, observability endpoints)
- Ops cluster: Inbound from workload clusters (for observability ingestion)
- Clusters don't need to reach each other (promotion is Git-driven)

**Security:**
- mTLS for observability endpoints (Envoy Gateway, Thanos gRPC)
- RBAC restricts who can create Applications targeting production
- Network policies isolate cluster communication
- Sealed secrets for credentials (cluster-specific keys)

## Disaster Recovery

**Ops Cluster Outage:**
- Workloads continue running (reconciliation pauses)
- Recovery: Restore Ops cluster, reapply bootstrap Application
- State rehydrates from Git (no data loss)

**Workload Cluster Outage:**
- Isolated failure (doesn't affect other clusters)
- Recovery: Restore cluster, Argo CD reconciles desired state
- Observability data may have gaps (acceptable for non-critical clusters)

## Future Considerations

- **Multi-Ops variant**: Can split into multiple Ops clusters if regulatory/geographic isolation needed
- **Regional aggregation**: Regional Ops clusters can feed global Ops for scale
- **Edge clusters**: Can run lightweight Argo CD for air-gapped scenarios

## References

- Repository: `README.md` (Global Operations Topology section)
- Bootstrap: `argocd-bootstrap-apps/`
- Design: See topology diagrams in `README.md`

