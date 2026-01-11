# Documentation

This directory contains comprehensive documentation for the Kubernetes platform. The documentation is organized by topic to help you find what you need quickly.

> **Note:** This documentation focuses on platform components and assumes you have already provisioned your Kubernetes clusters and cloud infrastructure. Infrastructure provisioning guides using Kubernetes-native tools (e.g., Crossplane) will be added in the future.

## Quick Start

**New to the platform?** Start here:

- [Getting Started Guide](getting-started.md) - Step-by-step walkthrough for bootstrapping the platform
- [FAQ](faq.md) - Common questions and answers
- [Troubleshooting Guide](troubleshooting.md) - Solutions to common issues

## Architecture & Design

**Understanding the platform architecture:**

- [Architecture Decision Records (ADRs)](adr/) - Documented rationale for major architectural choices
  - [ADR-001: Argo CD App-of-Apps Pattern](adr/0001-argocd-app-of-apps-pattern.md)
  - [ADR-002: Thanos for Metrics Aggregation](adr/0002-thanos-for-metrics-aggregation.md)
  - [ADR-003: Envoy Gateway Over Traditional Ingress](adr/0003-envoy-gateway-over-traditional-ingress.md)
  - [ADR-004: Sealed Secrets for Secret Management](adr/0004-sealed-secrets-for-secret-management.md)
  - [ADR-005: Centralized Ops Cluster Topology](adr/0005-centralized-ops-cluster-topology.md)
  - [ADR-006: Multi-Cluster GitOps Approach](adr/0006-multi-cluster-gitops-approach.md)

## Platform Components

**Deep-dive guides for major platform pillars:**

### Observability
- [Observability Guide](observability.md) - Metrics (Thanos), Logs (Elastic Stack), Traces (Jaeger)
- [Elasticsearch Best Practices](elastic-best-practices.md) - Node roles, mTLS, heap sizing, ILM, GC tuning
- [Alert Catalog](alert-catalog.md) - Available alerts and their purposes

### Traffic Management
- [Traffic Management Guide](traffic-management.md) - Envoy Gateway, TLS certificates, DNS automation
- [Envoy Gateway Best Practices](envoy-gateway-best-practices.md) - Production patterns, certificate management, observability, route management

### GitOps & Operations
- [Argo CD Best Practices](argocd-best-practices.md) - HA setup, custom labels, Redis, Gateway exposure, metrics

### Security & Compliance
- [Policy & Compliance Guide](compliance.md) - Kyverno policies, Checkov scanning, audit→enforce strategy

## Operational Guides

**Day-to-day operations and troubleshooting:**

- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
- [FAQ](faq.md) - Frequently asked questions
- [Alert Catalog](alert-catalog.md) - Understanding platform alerts

## Documentation by Use Case

### I want to...

**...bootstrap the platform for the first time**
→ [Getting Started Guide](getting-started.md)

**...understand why certain technologies were chosen**
→ [Architecture Decision Records](adr/)

**...set up observability (metrics, logs, traces)**
→ [Observability Guide](observability.md)

**...configure ingress and TLS**
→ [Traffic Management Guide](traffic-management.md)

**...implement security policies**
→ [Policy & Compliance Guide](compliance.md)

**...troubleshoot an issue**
→ [Troubleshooting Guide](troubleshooting.md)

**...optimize Elasticsearch**
→ [Elasticsearch Best Practices](elastic-best-practices.md)

**...configure Argo CD properly**
→ [Argo CD Best Practices](argocd-best-practices.md)

**...understand available alerts**
→ [Alert Catalog](alert-catalog.md)

**...find answers to common questions**
→ [FAQ](faq.md)

## Documentation Structure

```
docs/
├── README.md (this file)
├── getting-started.md          # Bootstrap walkthrough
├── observability.md             # Metrics, logs, traces
├── traffic-management.md        # Gateway API, TLS, DNS
├── compliance.md                 # Kyverno, Checkov
├── argocd-best-practices.md     # Argo CD configuration
├── elastic-best-practices.md    # Elasticsearch optimization
├── troubleshooting.md           # Common issues
├── faq.md                       # Questions & answers
├── alert-catalog.md             # Alert definitions
└── adr/                         # Architecture Decision Records
    ├── README.md
    └── [6 ADR files]
```

## Contributing to Documentation

Found an issue or want to improve the documentation?

1. Check if there's an existing [documentation issue](https://github.com/Thakurvaibhav/k8s/issues?q=is%3Aissue+label%3Adocumentation)
2. Open a new [documentation issue](https://github.com/Thakurvaibhav/k8s/issues/new?template=documentation.md)
3. Submit a pull request with your improvements

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

## Related Resources

- [Main README](../README.md) - Platform overview and inventory
- [AGENTS.md](../AGENTS.md) - Repository conventions and structure
- [SECURITY.md](../SECURITY.md) - Security policy and practices
- [CONTRIBUTING.md](../CONTRIBUTING.md) - How to contribute

