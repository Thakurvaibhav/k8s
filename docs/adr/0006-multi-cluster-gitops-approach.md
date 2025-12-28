# ADR-006: Multi-Cluster GitOps with Single Control Plane

## Status
Accepted

## Context

I needed a GitOps strategy that manages multiple Kubernetes clusters (dev, staging, prod, ops) while maintaining:

- **Consistency**: Same components deployed consistently across clusters
- **Isolation**: Environments isolated (dev changes don't affect prod)
- **Promotion**: Safe promotion path (dev → staging → prod)
- **Auditability**: All changes tracked and auditable
- **Scalability**: Easy to add new clusters or environments
- **Operational simplicity**: Minimal manual intervention

Traditional approaches have limitations:
- **Per-cluster GitOps**: Each cluster has its own GitOps tool (drift, inconsistency)
- **Manual kubectl**: Not declarative, error-prone, no audit trail
- **Copy-paste configs**: High duplication, drift risk
- **Terraform/Ansible**: Not GitOps-native, requires external tooling
- **Helm-only**: No continuous reconciliation, manual upgrades

## Decision

I implemented a **multi-cluster GitOps approach** using:

1. **Single Argo CD Control Plane** (in ops cluster) managing all clusters
2. **App-of-Apps Pattern** (Helm chart) generating Applications for all components
3. **Environment-Specific Values Files** (`values.dev-01.yaml`, `values.prod-01.yaml`) for overrides
4. **Git Branching Model** (dev → staging → stable) for promotion
5. **Cluster Registration** (remote clusters registered in Argo CD via cluster secrets)

**Key Components:**

**Bootstrap Applications:**
- Located in `argocd-bootstrap-apps/` (one per cluster)
- Creates root Application pointing to `app-of-apps` Helm chart
- Applied once per cluster to bootstrap GitOps

**App-of-Apps Chart:**
- Generates Argo CD `Application` resources for each enabled component
- Uses environment values files to customize per-cluster behavior
- Manages sync waves for dependency ordering
- Provides feature flags (`enable` toggles) per component

**Git Promotion Flow:**
- `dev` branch → `dev-01` cluster (tracks `HEAD` or `dev` branch)
- `staging` branch → `stag-01` cluster (tracks `staging` branch)
- `stable` tag → `prod-01` and `ops-01` clusters (tracks `stable` tag)
- Promotion: Merge dev → staging, then tag `stable` from staging

**Cluster Targeting:**
- Applications specify `destination.cluster` and `destination.namespace`
- Ops cluster manages Applications, but resources deploy to target clusters
- Remote clusters registered via `kubectl` or Argo CD CLI

## Consequences

### Positive

- **Single source of truth**: One Git repo, one Argo CD, manages all clusters
- **Consistency**: Same chart versions and patterns across clusters (with environment overrides)
- **Promotion safety**: Git-driven promotion (dev → staging → stable) prevents accidental prod changes
- **Audit trail**: All changes in Git history + Argo CD event log
- **Scalability**: Add new cluster = add bootstrap file + values file
- **Operational efficiency**: One UI shows all clusters and applications
- **Declarative**: Everything in Git, no manual kubectl operations
- **Self-healing**: Argo CD continuously reconciles desired state
- **Rollback**: Git revert or tag rollback reverts all clusters
- **Feature flags**: Enable/disable components per environment via values

### Negative

- **Ops cluster dependency**: Ops cluster outage pauses reconciliation (workloads keep running)
- **Network requirement**: All clusters must reach Ops cluster (outbound)
- **Initial complexity**: More complex than single-cluster setup
- **Learning curve**: Requires understanding Argo CD, App-of-Apps, multi-cluster concepts
- **Git workflow**: Requires disciplined branching and tagging
- **Cluster registration**: Must register remote clusters (one-time per cluster)

### Mitigations

- **Documentation**: Comprehensive guides in `docs/getting-started.md` and `README.md`
- **Bootstrap automation**: Scripts to generate bootstrap files
- **Monitoring**: Alert on Argo CD sync failures or cluster connectivity
- **Documentation**: Comprehensive guides on GitOps and Argo CD concepts
- **Runbooks**: Documented procedures for common operations

## Alternatives Considered

### 1. Per-Cluster GitOps (Argo CD in Each Cluster)
**Rejected because:**
- Operational overhead (manage Argo CD in 5+ clusters)
- No unified view (must check each cluster separately)
- Configuration drift (different Argo CD versions/configs)
- Higher costs (Argo CD resources in every cluster)
- Difficult coordination (which cluster to check for status?)

### 2. Flux Instead of Argo CD
**Rejected because:**
- Flux is an excellent GitOps tool with strong declarative capabilities
- Argo CD's UI and multi-cluster management features better suited this use case
- Argo CD Application CRDs provided more flexibility for this specific architecture
- Both are excellent choices; Argo CD's ecosystem and features aligned better with requirements

### 3. Terraform for Multi-Cluster Management
**Rejected because:**
- Terraform is excellent for infrastructure provisioning and management
- For application deployment orchestration, GitOps tools provide better continuous reconciliation
- Terraform state management adds complexity for this use case
- Kubernetes-native resources (via GitOps) provide better integration than Terraform providers
- Terraform would be an excellent choice for infrastructure-as-code, but this focused on application deployment

### 4. Helm-Only (No GitOps Tool)
**Rejected because:**
- No continuous reconciliation (must run `helm upgrade` manually)
- No self-healing (drift not automatically corrected)
- No unified view across clusters
- Manual promotion process (error-prone)

### 5. GitOps per Environment (Separate Repos)
**Rejected because:**
- Configuration duplication across repos
- Difficult to keep charts in sync
- Promotion requires copying between repos
- No unified audit trail

### 6. Kustomize-Based App-of-Apps
**Rejected because:**
- Less flexible for conditional logic (enable/disable toggles)
- Harder to manage per-environment git revisions
- Kustomize overlays don't scale well for many environments
- Helm provides better templating for complex scenarios

## Implementation Details

**Bootstrap Process:**
1. Register remote cluster in Argo CD: `argocd cluster add <context>`
2. Apply bootstrap Application: `kubectl apply -f argocd-bootstrap-apps/<cluster>.yaml`
3. Bootstrap Application installs `app-of-apps` chart with cluster-specific values
4. Chart generates Applications for all enabled components
5. Argo CD syncs Applications, deploying resources to target cluster

**Application Naming:**
- Pattern: `<cluster-name>-<component-name>` (e.g., `dev-01-monitoring`)
- Enables easy filtering: `argocd app list --selector cluster=dev-01`
- Clear ownership: Name indicates which cluster component belongs to

**Values File Strategy:**
- Base: `values.yaml` (common defaults, rarely changed)
- Environment: `values.<env>.yaml` (environment-specific overrides)
- Promotion: Change `source.targetRevision` in values file
- Feature flags: `enable` toggles in values files

**Sync Wave Management:**
- Annotations: `argocd.argoproj.io/sync-wave: "-5"` (negative = early, positive = late)
- Dependencies: Sealed Secrets (-5) → Cert-Manager (0) → Envoy Gateway (1) → Apps (5+)
- Ensures correct deployment order across all clusters

## Promotion Workflow

1. **Development**: Merge to `dev` branch → auto-syncs `dev-01` cluster
2. **Staging**: Merge `dev` → `staging` branch → auto-syncs `stag-01` cluster
3. **Production**: Tag `stable` from `staging` → `prod-01` and `ops-01` track `stable` tag
4. **Emergency**: Branch off `stable`, fix, retag, forward-merge to `staging` and `dev`

**Benefits:**
- Immutable production (always references `stable` tag)
- Fast iteration in dev (tracks `HEAD`)
- Soak testing in staging before production
- Clear audit trail (Git tags and branches)

## Monitoring & Observability

- **Argo CD Metrics**: Prometheus scrapes Argo CD metrics
- **Application Health**: Argo CD UI shows sync status per cluster
- **Drift Detection**: Argo CD detects and reports configuration drift
- **Event Logging**: All sync events logged in Argo CD
- **Alerts**: Alert on sync failures, drift, or cluster connectivity issues

## References

- [Argo CD Multi-Cluster Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-management/)
- Repository: `charts/app-of-apps/`, `argocd-bootstrap-apps/`
- Design: `README.md` (Branching & Promotion Model, Central Command & Control sections)

