# Alert Catalog

> Generated/maintained from files in `charts/monitoring/configs/alert-rules/*-rules.yaml`. Keep rule source of truth in Prometheus rule files; update this catalog when adding / modifying alerts.

## Contents
- [Deployment](#deployment)
- [Pods](#pods)
- [Nodes](#nodes)
- [BlackBox / Synthetic](#blackbox--synthetic)
- [Envoy Gateway](#envoy-gateway)
- [Elasticsearch](#elasticsearch)
- [Kyverno](#kyverno)

Legend: `for` = evaluation window.

---
## Deployment
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| Deployment at 0 Replicas | 1m | critical | devops | Deployment has zero running replicas. (sum kube_deployment_status_replicas < 1) | Check recent deploy / image pull / events (`kubectl describe deploy`); inspect pods `kubectl get pods -l deployment` |
| HPA Scaling Limited | 1m | warning | devops | HPA condition ScalingLimited=true (cannot scale further) | Confirm HPA max replicas vs workload; review CPU/memory metrics; consider raising max or optimizing app |
| HPA at MaxCapacity | 1m | critical | devops | Current replicas reached spec.maxReplicas | Capacity plan: validate traffic spike vs leak; right-size resources |

---
## Pods
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| Container restarted | 0m | warning | slack | Any container restart in last 5m (increase restarts > 0) | `kubectl logs --previous`; check OOMKilled / CrashLoopBackOff |
| Too many Container restarts | 0m | critical | dev | >5 restarts in 15m | Triage root cause (OOM, crash); add liveness/readiness? |
| Container Not Ready | 4m | warning | dev | Ready condition false for container (excluding certain namespaces) | Inspect readiness probe, logs, events |
| High Memory Usage of Container | 5m | warning | dev | >80% memory limit usage | Confirm limit correctness; heap/profile; potential leak |
| High CPU Usage of Container | 5m | warning | dev | >80% CPU quota usage | Check saturation vs throttling; optimize code; scale HPA |
| CPU Throttling of Container | 5m | warning | slack | >75% periods throttled | Increase CPU limit or reduce bursts; analyze pprof / load |
| High Persistent Volume Usage | 5m | warning | devops | PVC >60% used | Confirm growth trend; expand PVC / enable auto-expansion; cleanup data |

---
## Nodes
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| High Node Memory Usage | 5m | warning | devops | >80% node memory used | Check top pods (`kubectl top pods --sort-by=memory`); evict / reallocate |
| High Node CPU Usage | 10m | warning | devops | >80% allocatable CPU used | Identify noisy pods; consider cluster scale out |
| High Node Disk Usage | 5m | warning | devops | >85% disk used | Prune images, logs; expand node disks / add nodes |

---
## BlackBox / Synthetic
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| Probe Failed | 1m | (none) | devops | probe_success == 0 | Validate target endpoint manually; check network / DNS / TLS |
| SSL Certificate Expiry | 5m | (none) | devops | Cert expires <10 days | Renew cert (cert-manager / issuer); verify secret rotation |

---
## Envoy Gateway
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| Gateway Route High 4xx Error Count | 5m | warning | slack | 4xx ratio >50% | Distinguish client errors vs misroute; analyze logs; confirm config |
| Gateway Route High 5xx Error Count | 5m | warning | slack | 5xx ratio >50% | Check upstream health; rollback recent deploy; inspect envoy stats |
| Gateway Route Critical 4xx Error Count | 5m | warning | devops | 4xx ratio >75% | Same as High 4xx; escalate if sustained |
| Gateway Route Critical 5xx Error Count | 5m | critical | devops | 5xx ratio >75% | Incident: trace failing upstream; scale or revert |
| Gateway High P90 Latency | 15m | warning | slack | P90 >500ms | Check upstream latency, resource pressure, retries timeouts |

---
## Elasticsearch
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| ElasticSearch Status RED | 3m | critical | devops | cluster_health status=red | Identify missing primaries (`_cat/indices`); check node status; restore replicas |
| ElasticSearch Status YELLOW | 5m | warning | devops | cluster_health status=yellow | Undistributed replicas or initializing shards; capacity / allocation explain |
| ElasticSearch Health Missing | 5m | warning | slack | exporter scrape failing | Check exporter pod/logs; TLS / auth; ES endpoint health |

---
## Kyverno
| Alert | For | Severity | Team | Purpose / Trigger | First Actions |
|-------|-----|----------|------|-------------------|---------------|
| Kyverno enforced policy failed | 1m | warning | devops | rate(fail results, enforce mode) > 0 | Inspect policy name / rule; fetch recent violations; decide rollback vs remediation |

---

### Maintenance Process
1. Propose new rule (PR modifying *-rules.yaml) including rationale + runbook stub.
2. Run `promtool check rules` in CI (add if missing).
3. Update this catalog section/table in same PR.
4. Tag severity + owner; require review from platform + service owner for critical.
5. Periodic prune: remove alerts with chronic noise (MTTA > threshold) after root cause.

> Keep expressions authoritative in rule files; this document summarizes purpose and triage.

