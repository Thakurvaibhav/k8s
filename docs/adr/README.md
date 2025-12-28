# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) documenting significant architectural decisions made for this Kubernetes platform.

## What are ADRs?

ADRs are documents that capture important architectural decisions along with their context and consequences. They help:

- **Preserve knowledge**: Understand why decisions were made, not just what was implemented
- **Enable better decisions**: Learn from past trade-offs when making future choices
- **Onboard new team members**: Quickly understand the reasoning behind platform design
- **Facilitate discussions**: Provide structured format for evaluating alternatives

## ADR Format

Each ADR follows this structure:

- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: The issue motivating this decision
- **Decision**: The change we're proposing or have agreed to implement
- **Consequences**: What becomes easier or more difficult because of this change
- **Alternatives Considered**: Other options that were evaluated

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](0001-argocd-app-of-apps-pattern.md) | Use Argo CD App-of-Apps Pattern | Accepted |
| [ADR-002](0002-thanos-for-metrics-aggregation.md) | Use Thanos for Multi-Cluster Metrics Aggregation | Accepted |
| [ADR-003](0003-envoy-gateway-over-traditional-ingress.md) | Use Envoy Gateway Over Traditional Ingress Controllers | Accepted |
| [ADR-004](0004-sealed-secrets-for-secret-management.md) | Use Sealed Secrets for GitOps Secret Management | Accepted |
| [ADR-005](0005-centralized-ops-cluster-topology.md) | Centralized Ops Cluster Topology | Accepted |
| [ADR-006](0006-multi-cluster-gitops-approach.md) | Multi-Cluster GitOps with Single Control Plane | Accepted |

## Contributing

When making a significant architectural decision:

1. Create a new ADR using the template
2. Number it sequentially (e.g., `0007-<title>.md`)
3. Update this README with the new entry
4. Set status to "Proposed" initially
5. After review and acceptance, update status to "Accepted"

## References

- [ADR Template](https://adr.github.io/)

