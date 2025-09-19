# eck-operator Helm Chart

## Overview
This chart vendors the upstream Elastic Cloud on Kubernetes (ECK) Operator Helm chart and exposes it as a standalone install or as a dependency for higher‑level platform charts (notably `elastic-stack`). It contains no additional templates beyond the upstream operator at this time.

## Upstream Dependency
Declared in `Chart.yaml`:
```
dependencies:
  - name: eck-operator
    version: 2.16.1
    repository: https://helm.elastic.co
```

## Usage Modes
| Mode | Description |
|------|-------------|
| Standalone | Install only the operator to prepare a cluster for later Elastic resources (Elasticsearch, Kibana, Beats). |
| Dependency | Pulled automatically when installing the `elastic-stack` chart (if `eckOperator.enable=true`). |

## Why Separate Operator?
Separating the operator allows:
- Version pinning and controlled upgrades independent of stack resources.
- Installing CRDs / controllers early (pre‑creating Elasticsearch/Kibana/Filebeat objects in Git).
- Consistent operator version across multiple clusters (shipping logs to a central cluster) while leaving stack composition flexible.

## Install (Standalone)
```bash
helm dependency update ./eck-operator
helm upgrade --install eck-operator ./eck-operator -n elastic-system --create-namespace
```

## Upgrade Strategy
1. Review Elastic release notes for CRD or behavior changes.
2. Bump dependency version in `Chart.yaml`.
3. Run `helm dependency update ./eck-operator`.
4. Upgrade in a lower environment first, validate operator & existing resources.

## Removal
Uninstalling the operator does not automatically delete managed Elasticsearch / Kibana clusters. Remove those CRs first if you intend a full teardown.

## License
Internal use unless otherwise specified. Refer to Elastic licensing for upstream operator components.
