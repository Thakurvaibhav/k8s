# AGENTS.md - AI Agent Guide

This document provides guidance for AI agents working with this Kubernetes platform repository. It outlines repository structure, conventions, common tasks, and important considerations.

## Repository Overview

This repository contains Helm charts implementing a "Platform in a Box" - a GitOps-driven Kubernetes platform foundation using Argo CD's App-of-Apps pattern. The platform includes:

- **Traffic Management**: Envoy Gateway, NGINX Ingress Controller, External DNS
- **Observability**: Prometheus/Thanos (metrics), Elastic Stack (logs), Jaeger (traces)
- **Security & Compliance**: Sealed Secrets, Cert-Manager, Kyverno policies
- **Data Services**: Redis
- **GitOps Orchestration**: Argo CD App-of-Apps pattern

## Key Repository Structure

```
k8s/
├── argocd-bootstrap-apps/     # Bootstrap Application manifests for each cluster
│   ├── dev-01.yaml
│   ├── ops-01.yaml
│   ├── prod-01.yaml
│   └── stag-01.yaml
├── charts/                     # Helm charts for platform components
│   ├── app-of-apps/           # Root orchestrator chart
│   ├── cert-manager/
│   ├── envoy-gateway/
│   ├── external-dns/
│   ├── kyverno/
│   ├── logging/               # Elastic Stack (ECK operator)
│   ├── monitoring/            # Prometheus/Thanos
│   ├── nginx-ingress-controller/
│   ├── redis/
│   ├── sealed-secrets/
│   └── jaeger/
├── docs/                      # Detailed architecture and operational guides
│   ├── getting-started.md
│   ├── observability.md
│   ├── traffic-management.md
│   ├── compliance.md
│   ├── argocd-best-practices.md
│   ├── elastic-best-practices.md
│   ├── troubleshooting.md
│   ├── faq.md
│   └── alert-catalog.md
├── scripts/                   # CI/CD and utility scripts
│   ├── scan.sh               # Chart scanning (lint, trivy, checkov)
│   ├── scan-config.yaml      # Scan configuration
│   ├── junit.tpl             # JUnit template for test results
│   └── what-runs-where.sh
└── README.md                  # Main documentation

```

## Critical Conventions

### 1. Branching & Promotion Model

**NEVER modify production values directly.** Follow the promotion flow:

- `dev` branch → `dev-01` cluster (fast iteration)
- `staging` branch → `stag-01` cluster (soak testing)
- `stable` tag → `prod-01` and `ops-01` clusters (immutable production)

**Key Rules:**
- Production always references `stable` tag (immutable)
- Environment-specific values files: `values.<env>.yaml` (e.g., `values.prod-01.yaml`)
- When modifying charts, start in `dev` branch and promote through the pipeline
- Emergency prod fixes: branch off `stable`, fix, retag, then forward-merge to `staging` and `dev`

### 2. Values File Pattern

Each chart has environment-specific values files:
- `values.yaml` - Base/default values
- `values.dev-01.yaml` - Development overrides
- `values.stag-01.yaml` - Staging overrides
- `values.ops-01.yaml` - Operations cluster overrides
- `values.prod-01.yaml` - Production overrides

**When modifying values:**
- Update the appropriate environment file(s)
- Keep base `values.yaml` minimal (common defaults only)
- Environment files should override, not duplicate base values

### 3. Component Enablement

Components are controlled via feature flags in `app-of-apps/values.yaml`:

```yaml
sealedSecrets:
  enable: false  # Toggle component on/off
  # ... other config
```

**Important:** When adding new components or modifying existing ones:
- Update the `app-of-apps` chart to include the new component
- Add enable/disable toggle in base `values.yaml`
- Create environment-specific overrides if needed
- Update the Inventory table in `README.md`

### 4. Sync Waves

Argo CD sync waves control deployment order. Lower numbers deploy first:

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "-5"  # Deploys early (negative = before 0)
  argocd.argoproj.io/sync-wave: "5"   # Deploys later
```

**Dependencies:**
- Sealed Secrets: `-5` (foundational)
- Envoy Gateway: `-2` (needed by other components)
- External DNS: `-3` (needed for DNS automation)
- Most components: `0` (default)
- Applications: `5+` (deploy after platform)

## Common Tasks

### Adding a New Chart

1. **Create chart structure:**
   ```bash
   charts/new-component/
   ├── Chart.yaml
   ├── values.yaml
   ├── values.dev-01.yaml
   ├── values.ops-01.yaml
   ├── values.prod-01.yaml
   ├── values.stag-01.yaml
   ├── templates/
   │   └── [templates]
   └── README.md
   ```

2. **Add to `app-of-apps` chart:**
   - Add component block in `charts/app-of-apps/values.yaml`
   - Add template in `charts/app-of-apps/templates/` (if needed)
   - Include enable toggle and standard fields (project, namespace, source)

3. **Update documentation:**
   - Add entry to Inventory table in `README.md`
   - Document dependencies in Cross-Chart Relationships section
   - Create component-specific README if complex

4. **Test:**
   ```bash
   helm template charts/new-component -f charts/new-component/values.dev-01.yaml
   helm lint charts/new-component
   scripts/scan.sh lint
   ```

### Modifying Existing Charts

1. **Always test locally first:**
   ```bash
   # Template rendering
   helm template charts/<component> -f charts/<component>/values.dev-01.yaml
   
   # Linting
   helm lint charts/<component>
   
   # Full scan
   scripts/scan.sh lint
   scripts/scan.sh trivy
   scripts/scan.sh checkov
   ```

2. **Update appropriate values file:**
   - Development changes: `values.dev-01.yaml`
   - Production changes: `values.prod-01.yaml` (but promote through pipeline!)
   - Base changes: `values.yaml` (affects all environments)

3. **Consider dependencies:**
   - Check Cross-Chart Relationships in README
   - Verify sync waves are appropriate
   - Update dependent components if needed

### Updating Documentation

1. **Component changes:**
   - Update chart's `README.md` if it exists
   - Update Inventory table in main `README.md`
   - Update Cross-Chart Relationships if dependencies change

2. **Architecture changes:**
   - Update relevant doc in `docs/` folder
   - Update main `README.md` if high-level changes
   - Update diagrams if topology changes

3. **Operational changes:**
   - Update `docs/troubleshooting.md` if common issues change
   - Update `docs/faq.md` if new questions arise
   - Update `docs/getting-started.md` if bootstrap flow changes

## Important Considerations

### Security

- **Sealed Secrets:** Never commit unsealed secrets. Use `kubeseal` to seal before committing.
- **Credentials:** All sensitive data should be in sealed secrets or external secret management.
- **RBAC:** Service accounts should follow least privilege principle.
- **TLS:** Always use TLS for external-facing services; cert-manager handles issuance.

### Multi-Cluster Awareness

- **Ops Cluster:** Central command & control; hosts Argo CD, observability backends
- **Workload Clusters:** Dev, Stage, Prod - execution targets only
- **Application Destinations:** Check `destination.cluster` and `destination.namespace` in Application specs
- **Remote Clusters:** Must be registered in Argo CD (cluster secrets)

### Chart Dependencies

Key dependencies to remember:
- **Sealed Secrets** → Most components (for credentials)
- **Cert-Manager** → Envoy Gateway, Logging, Jaeger (for TLS)
- **External DNS** → Envoy Gateway (for DNS records)
- **Envoy Gateway** → Monitoring (Thanos gRPC), Logging (mTLS ingest)
- **Logging (Elasticsearch)** → Jaeger (for span storage)
- **ECK Operator** → Logging (Elastic Stack deployment)

### Testing & Validation

**Before committing:**
1. Run `helm lint` on modified charts
2. Run `helm template` to verify rendering
3. Run `scripts/scan.sh lint` to check for double document separators
4. Run `scripts/scan.sh trivy` to scan container images
5. Run `scripts/scan.sh checkov` for security policy checks

**Scan Configuration:**
- Skipped charts/images: `scripts/scan-config.yaml`
- Per-chart ignores: `.trivyignore`, `.checkov.yaml` in chart directory
- Global Checkov config: `.globalcheckov.yaml` (if exists)

### Version Management

- **Chart Versions:** Bump `version` in `Chart.yaml` when making template/value changes
- **App Versions:** Update `appVersion` in `Chart.yaml` when upgrading component versions
- **Git Tags:** Use semantic versioning for `stable` tags (e.g., `stable-v1.2.3`)

## File-Specific Guidelines

### `argocd-bootstrap-apps/*.yaml`
- Bootstrap Applications that install the `app-of-apps` chart
- One file per cluster (dev-01, ops-01, prod-01, stag-01)
- Points to appropriate values file via Helm valueFiles
- **Rarely modified** - only when adding new clusters or changing bootstrap approach

### `charts/app-of-apps/values.yaml`
- Root configuration for all platform components
- Contains enable toggles and component definitions
- Each component block includes: enable, project, namespace, source, annotations
- **Modify carefully** - affects all clusters

### `charts/*/templates/`
- Helm templates using Go templating
- Follow Helm best practices (use `_helpers.tpl` for common functions)
- Use `include` for reusable template snippets
- Test with `helm template` before committing

### `scripts/scan.sh`
- CI/CD scanning script (lint, trivy, checkov)
- Respects `scan-config.yaml` for skip lists
- Outputs JUnit XML for CI integration
- Can be run locally for validation

## Common Pitfalls to Avoid

1. **Don't modify production values directly** - Always promote through dev → staging → stable
2. **Don't commit unsealed secrets** - Always use `kubeseal` first
3. **Don't break sync wave ordering** - Verify dependencies before changing sync waves
4. **Don't skip testing** - Always run `helm lint` and `helm template` before committing
5. **Don't forget to update documentation** - Keep README and docs in sync with code changes
6. **Don't ignore scan failures** - Address lint, trivy, and checkov issues before merging
7. **Don't hardcode cluster-specific values** - Use environment values files instead
8. **Don't create circular dependencies** - Be careful with cross-chart relationships

## Getting Help

- **Architecture Questions:** See `docs/` folder for detailed guides
- **Common Issues:** Check `docs/troubleshooting.md` and `docs/faq.md`
- **Component Details:** See individual chart `README.md` files
- **Bootstrap Flow:** See `README.md` Bootstrap Flow section
- **Best Practices:** See `docs/argocd-best-practices.md`, `docs/elastic-best-practices.md`

## Quick Reference

**Key Commands:**
```bash
# Template rendering
helm template charts/<component> -f charts/<component>/values.<env>.yaml

# Linting
helm lint charts/<component>

# Full scan
scripts/scan.sh lint
scripts/scan.sh trivy
scripts/scan.sh checkov

# Bootstrap (in ops cluster)
kubectl apply -f argocd-bootstrap-apps/ops-01.yaml

# Check Argo CD status
kubectl get applications -n argocd
argocd app list
```

**Key Files:**
- `README.md` - Main documentation and inventory
- `charts/app-of-apps/values.yaml` - Component enablement
- `scripts/scan-config.yaml` - Scan skip configuration
- `docs/getting-started.md` - Step-by-step bootstrap guide

**Key Concepts:**
- App-of-Apps pattern: Root Application manages component Applications
- GitOps: Git is single source of truth
- Progressive enablement: Feature flags via values
- Environment parity: Same charts, different values per environment

