# ADR-002: Use Thanos for Multi-Cluster Metrics Aggregation

## Status
Accepted

## Context

I operate multiple Kubernetes clusters (dev, staging, prod, ops) and need a unified metrics platform that provides:

- **Long-term retention**: Store metrics for months/years for capacity planning and historical analysis
- **Global querying**: Single query interface across all clusters without maintaining separate Prometheus instances
- **High availability**: Survive individual Prometheus pod failures
- **Cost efficiency**: Store compressed, downsampled data in object storage
- **Scalability**: Handle growing metric cardinality without constant Prometheus scaling
- **Consistency**: Same query language (PromQL) across all environments

Traditional Prometheus-only approaches have limitations:
- **Limited retention**: Prometheus local storage typically holds 2-4 weeks of data
- **No global view**: Each cluster has isolated Prometheus, requiring manual federation
- **Single point of failure**: Prometheus pod failure loses recent data
- **Storage costs**: Replicating full-resolution data across clusters is expensive
- **Query complexity**: Federating queries across multiple Prometheus instances is cumbersome

## Decision

I implemented **Thanos** in a sidecar architecture with the following components:

1. **Thanos Sidecar**: Attached to each Prometheus pod, uploads blocks to object storage (GCS/S3)
2. **Thanos Store Gateway**: Serves historical data from object storage
3. **Thanos Query (Querier)**: Global query endpoint that aggregates real-time (Prometheus) and historical (Store) data
4. **Thanos Compactor**: Runs in all clusters, downsamples and compresses historical data
5. **Thanos Ruler**: Optional, for global alerting rules

**Architecture:**
- Each cluster runs Prometheus + Thanos Sidecar (real-time metrics)
- Each cluster runs Thanos Compactor (downsamples and compresses data)
- Ops cluster hosts Thanos Query and Store Gateway (global aggregation)
- All clusters write to shared object storage bucket (per-environment buckets for isolation)
- Grafana queries Thanos Query, not individual Prometheus instances

**Key Configuration:**
- Object storage: GCS buckets with lifecycle policies
- Retention: 2h raw, 6h 5m downsampled, 24h 1h downsampled, 30d 1h downsampled
- External labels: `cluster`, `environment` for multi-cluster queries
- gRPC exposure: Thanos Query exposed via Envoy Gateway for secure cross-cluster access

## Consequences

### Positive

- **Unified query interface**: Single endpoint (Thanos Query) for all metrics across all clusters
- **Long-term retention**: Years of historical data in cost-effective object storage
- **High availability**: Prometheus pod failure doesn't lose data (already in object storage)
- **Cost efficiency**: Downsampling reduces storage by 90%+ for older data
- **Scalability**: Can add clusters without changing query infrastructure
- **Global alerts**: Thanos Ruler enables cross-cluster alerting rules
- **No data loss**: Sidecar uploads blocks continuously, not on shutdown
- **Standard PromQL**: Developers use familiar Prometheus query language

### Negative

- **Complexity**: More components to operate and monitor (Sidecar, Store, Query, Compactor)
- **Operational overhead**: Object storage bucket management, lifecycle policies, IAM
- **Query latency**: Historical queries may be slower (object storage vs local SSD)
- **Storage costs**: Object storage still incurs costs (though much lower than full retention)
- **Learning curve**: Requires understanding Thanos concepts (blocks, downsampling, external labels)
- **Debugging**: Issues span multiple components (Prometheus, Sidecar, Store, Query)

### Mitigations

- Comprehensive documentation in `docs/observability.md`
- Monitoring of Thanos components themselves (meta-monitoring)
- Clear runbooks for common issues
- Gradual rollout (start with single cluster, expand)
- Use Thanos Query UI for debugging query execution

## Alternatives Considered

### 1. Prometheus Federation
**Rejected because:**
- No long-term retention (federated Prometheus still has local storage limits)
- Complex query patterns (need to know which Prometheus to query)
- No global view without additional aggregation layer
- Doesn't solve HA problem (federating Prometheus can still fail)

### 2. Cortex
**Rejected because:**
- More complex architecture (requires object storage, chunks storage, query frontend)
- Different query model (not pure PromQL compatibility)
- Higher operational overhead
- Less mature ecosystem than Thanos

### 3. VictoriaMetrics
**Rejected because:**
- Different storage format (not Prometheus-compatible)
- Migration complexity from existing Prometheus setups
- Smaller community than Thanos
- Less proven at multi-cluster scale

### 4. Multiple Independent Prometheus Instances
**Rejected because:**
- No unified querying (must query each cluster separately)
- Limited retention (2-4 weeks typical)
- High storage costs (full resolution data in each cluster)
- No global alerting capabilities
- Operational overhead of managing many Prometheus instances

### 5. Managed Solutions (Datadog, New Relic, etc.)
**Rejected because:**
- Vendor lock-in
- High cost at scale
- Data sovereignty concerns
- Less control over retention and query patterns
- I want to keep observability stack GitOps-managed

## Implementation Notes

- Thanos Query exposed via Envoy Gateway with mTLS for secure cross-cluster access
- Separate object storage buckets per environment for isolation
- External labels (`cluster`, `environment`) enable filtering in queries
- Compactor runs in all clusters to process data locally before aggregation
- Store Gateway can be scaled horizontally if query load increases

## References

- [Thanos Documentation](https://thanos.io/tip/thanos/getting-started.md/)
- Repository: `charts/monitoring/`
- Design doc: `docs/observability.md`

