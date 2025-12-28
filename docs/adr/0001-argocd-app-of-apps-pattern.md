# ADR-001: Use Argo CD App-of-Apps Pattern

## Status
Accepted

## Context

I needed a GitOps orchestration strategy for managing a complex, multi-component Kubernetes platform across multiple clusters. The platform consists of 10+ interdependent components (monitoring, logging, ingress, secrets management, policy enforcement, etc.) that need to be:

- Deployed in a specific order (dependencies)
- Managed consistently across environments (dev, staging, prod, ops)
- Versioned and promoted through environments
- Toggled on/off per environment
- Maintained with minimal boilerplate

Traditional approaches had limitations:
- **Manual Application creation**: Each component requires a separate Argo CD Application manifest, leading to 50+ YAML files to maintain
- **Copy-paste duplication**: Environment-specific values duplicated across many files
- **Inconsistent naming**: No standard naming convention, making discovery difficult
- **Error-prone sync ordering**: Manual management of dependencies and sync waves
- **Difficult promotion**: Changing git revisions requires updating many files

## Decision

I adopted the **App-of-Apps pattern** using a Helm chart (`charts/app-of-apps`) that generates Argo CD `Application` resources declaratively.

The pattern works as follows:
1. A single bootstrap Application (e.g., `argocd-bootstrap-apps/ops-01.yaml`) installs the `app-of-apps` Helm chart
2. The chart renders `Application` CRs for each enabled component based on values
3. Each component block in `values.yaml` includes: enable toggle, project, namespace, source repo/path/revision, and optional annotations
4. Environment-specific overrides (`values.dev-01.yaml`, `values.prod-01.yaml`) customize per-cluster behavior
5. Sync waves control deployment order via annotations

**Key Features:**
- Single source of truth for component definitions
- Feature flags via `enable` toggles
- Environment parity with scoped overrides
- Git revision promotion (dev → staging → stable) via `targetRevision`
- Automatic sync wave management
- Consistent labeling and naming (`<cluster>-<component>`)

## Consequences

### Positive

- **Reduced boilerplate**: One chart generates all Applications instead of 50+ manual files
- **Consistent structure**: All Applications follow the same pattern, making them predictable
- **Easy promotion**: Change `targetRevision` in one values file to promote all components
- **Feature flags**: Enable/disable components per environment without deleting files
- **Dependency management**: Sync waves ensure correct deployment order
- **Maintainability**: Changes to Application structure (labels, annotations, sync options) happen in one place
- **Discoverability**: Clear naming convention (`<cluster>-<component>`) makes finding Applications trivial
- **GitOps alignment**: Everything is declarative and version-controlled

### Negative

- **Learning curve**: Requires understanding Helm templating to modify the chart
- **Debugging complexity**: Generated Applications require understanding the chart to troubleshoot
- **Chart versioning**: Changes to the `app-of-apps` chart affect all environments simultaneously
- **Less flexibility**: Harder to have truly unique Application configurations (though overrides help)
- **Initial setup**: More complex than creating individual Application files

### Mitigations

- Comprehensive documentation in `README.md` and `docs/getting-started.md`
- Clear examples in values files showing all available options
- Template helpers (`_helpers.tpl`) for common patterns
- Environment-specific overrides allow customization when needed
- AGENTS.md provides guidance for automated tooling

## Alternatives Considered

### 1. Individual Application Manifests
**Rejected because:**
- 50+ YAML files to maintain (10 components × 5 environments)
- High duplication and drift risk
- Difficult to ensure consistency
- Promotion requires updating many files

### 2. Kustomize-based App-of-Apps
**Rejected because:**
- Kustomize is excellent for simpler scenarios, but less flexible for conditional logic (enable/disable toggles)
- Managing per-environment git revisions is more complex with overlays
- Kustomize overlays become unwieldy with many environments
- Helm templating better suited for this use case with complex conditional requirements

### 3. Argo CD ApplicationSets
**Rejected because:**
- ApplicationSets excel at "one app, many clusters" scenarios with matrix generation
- For "many apps, many clusters" scenarios, the App-of-Apps pattern provides better organization
- Helm charts integrate well with existing tooling and workflows
- ApplicationSets are a powerful feature but add complexity not needed for this architecture

### 4. Terraform/Crossplane for Application Management
**Rejected because:**
- Terraform/Crossplane are excellent for infrastructure provisioning and management
- For managing Argo CD Applications specifically, staying Git-native (YAML/Helm) aligns better with GitOps principles
- Adding another tool would increase operational complexity
- The use case focuses on application deployment orchestration rather than infrastructure provisioning

## References

- [Argo CD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- Repository: `charts/app-of-apps/`
- Bootstrap files: `argocd-bootstrap-apps/`

