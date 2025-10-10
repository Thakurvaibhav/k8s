# Elasticsearch Best Practices (Kubernetes Platform)

Opinionated guidance for operating a production‑grade Elasticsearch (ES) deployment on Kubernetes using the Elastic Operator / Helm chart.

---
## 1. Cluster Architecture & Node Roles
Use distinct node sets (separate StatefulSets) for each role to isolate resource contention and scale independently:
- Master (cluster coordination only; low heap, stable CPU) – count = 3 (or 5 for very large clusters) to maintain quorum.
- Data (hot/warm/cold tiers; heavy disk & heap usage) – scale horizontally; separate storage classes per tier (fast NVMe for hot, cheaper SSD/HDD for warm/cold).
- Ingest (pipeline processors, enrich, geo, ML) – isolate CPU‑intensive ingest workloads from query/data nodes.
- (Optional) Coordinating / Client nodes – no data or master duties; front query layer (Large clusters / heavy search traffic).

Do NOT mix master + data on same Pod for production scale (recoveries & GC pauses on data nodes can trigger master instability).

Label all Pods with `es.node.role=<master|data-hot|data-warm|data-cold|ingest|coord>` and use node selectors / affinities:
```yaml
nodeSets:
  - name: master
    config.elasticsearch.node.roles: ["master"]
  - name: data-hot
    config.elasticsearch.node.roles: ["data_hot","data_content"]
  - name: ingest
    config.elasticsearch.node.roles: ["ingest"]
```

Enable anti‑affinity for master and data nodes to spread them across failure domains:
- Topology keys: `kubernetes.io/hostname`, zone labels (e.g. `topology.kubernetes.io/zone`).

---
## 2. Secure External Access (Gateway API + mTLS)
External access to Elasticsearch (outside cluster boundary) must be over mTLS:
- Terminate TLS & enforce client certs at Envoy Gateway (Gateway API) or an ingress controller.
- Use dedicated Gateway `HTTPRoute`/`TLSRoute` referencing Elasticsearch service (query or ingest endpoints).
- Client authentication: Issue client certs per application/team; rotate regularly; seal CA + certs via Sealed Secrets.
- Disable anonymous access and ensure security features (X-Pack) enabled.

Gateway API Example (pseudo):
```yaml
Gateway:
  name: es-gw
  listeners:
    - protocol: HTTPS
      tls:
        mode: Terminate
        certificateRef:
            secret: es-public-cert
HTTPRoute:
  rules:
    - matches: /
      backendRefs:
        - name: elasticsearch-coord
          port: 9200
```
Add mTLS policy extension (custom filter / AuthZ) requiring client cert signed by internal CA.

---
## 3. Resource Requests, Limits & JVM Heap Alignment
Every nodeSet must define CPU/memory requests & limits. Align JVM heap (`Xms`=`Xmx`) to a fraction of Pod memory:
- Recommended: Heap <= 50% of container memory to leave room for OS, Lucene structures, off‑heap, native memory.
- Never exceed 64GB RAM per node (compressed OOPS disabled > 32GB, diminishing returns > 64GB). Practical sweet spot: 8–32GB heap.
- Use environment variable or chart settings:
```yaml
resources:
  requests:
    cpu: "2"
    memory: "8Gi"
  limits:
    cpu: "4"
    memory: "8Gi"
env:
  - name: ES_JAVA_OPTS
    value: "-Xms4g -Xmx4g -XX:GCTimeRatio=9 -XX:ParallelGCThreads=4"
```
Tune GC thread count relative to CPU limits; avoid setting more GC threads than available vCPUs.

Validate: `/_nodes/jvm` and monitor heap usage vs container memory.

---
## 4. JVM Heap Guidance
- Keep heap small enough to reduce GC pause; large heaps slow full GCs & recovery.
- Prefer more nodes vs huge single nodes for shard parallelism & resilience.
- Use G1GC (default modern ES) unless proven need for CMS/Tuned collectors.
- Set equal Xms and Xmx to prevent heap resizing overhead.

---
## 5. Index Lifecycle Management (ILM)
Always enable ILM for retention & tiering:
- Hot → Warm → Cold → Delete policies reduce storage cost and overhead of massive active shard counts.
- Policy example: rollover by size (`max_size`), age (`max_age`), or docs count.
- Apply index templates referencing ILM policy. Ensure filebeat / ingest pipelines use index aliases for rollover.

Monitor ILM execution & backlog: `_ilm/explain`, adjust transition thresholds before shard explosion.

---
## 6. JVM & Performance Tuning (Advanced)
Augment `ES_JAVA_OPTS` for heavier workloads:
- `-XX:GCTimeRatio=9` : More aggressive GC time allowance (slightly higher throughput by spending a bit more time collecting).
- `-XX:ParallelGCThreads=<n>` : Match to CPU cores (e.g. half of limit for balanced scheduling). Example: `-XX:ParallelGCThreads=20` only if Pod really has ~20 vCPUs.
- Avoid oversetting threads (context switch cost). Keep within actual CPU limits.
- Consider `-XX:InitiatingHeapOccupancyPercent=30` for earlier concurrent cycles if using G1.
- Monitor GC metrics from `/_nodes/stats/jvm` and Prometheus exporter.

Do NOT blindly copy large GC thread counts from bare‑metal guidance; respect container CPU quota.

---
## 7. Shard & Index Strategy
- Limit shards per node: Aim < 20 shards/GB heap; excessive small shards waste resources.
- Consolidate indices for similar daily low‑volume sources (avoid index explosion).
- Use rollover instead of date‑suffix daily indices when volume is variable.
- Size primary shards so typical shard size is 20–50GB (hot tier) for efficient merges and search.

---
## 8. Operational Settings (Recovery & Allocation)
For large clusters / many indices tune allocation & recovery parameters:
- `cluster.routing.allocation.node_concurrent_recoveries` : Increase to accelerate shard recovery when capacity allows (default often conservative).
- `cluster.routing.allocation.cluster_concurrent_rebalance` : Control simultaneous rebalances.
- `indices.recovery.max_bytes_per_sec` (or `index.max_bytes_per_sec` older forms) : Raise when network & disk sustain faster recovery (e.g. `200mb` for NVMe + 10GbE).
- `indices.recovery.concurrent_streams` : More streams for parallel file transfers.

Balance faster recovery with query latency; monitor disk IO saturation.

---
## 9. ILM Poll Interval Tuning
If thousands of indices or ILM backlog observed:
- Adjust `indices.lifecycle.poll_interval` (default 10m). For high churn clusters reduce (e.g. `5m`) so actions (rollover, delete) trigger sooner.
- Avoid setting too low (<1m) as overhead can increase CPU usage. Empirically tune based on policy execution delays.

---
## 10. Monitoring & Alerting
Collect metrics:
- Node stats: heap %, old GC count/time, disk utilization, segment count.
- Cluster health: number of red/yellow indices, unassigned shards, pending tasks queue length.
- ILM lag: indices stuck in phase.
- Query latency percentiles & ingest pipeline latencies.

Alerts:
- Heap > 75% sustained
- GC time spikes / old gen count anomaly
- Unassigned shards > threshold
- Disk watermark approach (85%, 90% high watermark)
- ILM phase stall

Use Prometheus exporters or native Elastic monitoring; route alerts via Alertmanager or ElastAlert/Kibana watchers.

---
## 11. Security & Compliance
- Role Based Access Control: Restrict internal vs external roles; use service accounts and API keys over basic auth.
- Enforce TLS everywhere (intra-cluster encryption if crossing untrusted networks).
- mTLS for external clients; rotate certs; audit access.
- Enable audit logging for index access if compliance requires.
- Keep secrets (certs, credentials) sealed / encrypted in Git.

---
## 12. Backup & Disaster Recovery
- Snapshot to object storage (S3 / GCS) on schedule; test restore quarterly.
- Automate retention of snapshots (daily + weekly + monthly policy).
- Use incremental snapshots; ensure repository plugin access and credentials management (Sealed Secret).

---
## 13. Common Pitfalls / Anti‑Patterns
- Oversized heap ( > half Pod mem or > 32GB without need ) → long GC pauses.
- Mixing master/data/ingest roles on same nodes under load.
- Too many tiny shards (per-day indices for very small volumes).
- No ILM causing unbounded index growth & retention.
- Not tuning recovery throttle for large cluster rebalances.
- GC thread count > actual CPUs, causing thrash.
- Exposing ES over plain HTTP or TLS without client auth.

---
**Reference Commands**
- Heap stats: `curl -s https://es/_nodes/stats/jvm | jq '.nodes[] | .jvm.mem.heap_used_percent'`
- Unassigned shards: `curl -s https://es/_cat/shards?h=index,shard,state | grep UNASSIGNED`
- ILM status: `curl -s https://es/_ilm/explain | jq` 
- Recovery speed tuning (dynamic): `curl -XPUT https://es/_cluster/settings -H 'Content-Type: application/json' -d '{"transient":{"indices.recovery.max_bytes_per_sec":"150mb"}}'`

---
