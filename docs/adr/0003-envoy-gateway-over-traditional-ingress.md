# ADR-003: Use Envoy Gateway Over Traditional Ingress Controllers

## Status
Accepted

## Context

I needed a modern, scalable ingress solution for my multi-cluster Kubernetes platform that provides:

- **Standard API**: Use Kubernetes-native APIs (Gateway API) instead of vendor-specific annotations
- **Advanced routing**: Support for HTTP, HTTPS, gRPC, TCP, and UDP protocols
- **Policy enforcement**: Fine-grained traffic policies (rate limiting, circuit breaking, retries)
- **Observability**: Rich metrics and distributed tracing integration
- **Security**: mTLS support, WAF capabilities, OAuth integration
- **Multi-protocol**: Support for both traditional HTTP and modern gRPC workloads
- **Future-proof**: Aligned with Kubernetes Gateway API standard (not deprecated Ingress)

Traditional Ingress controllers (NGINX, Traefik, etc.) have limitations:
- **Vendor-specific annotations**: Each controller uses different annotations, creating lock-in
- **Limited protocol support**: Primarily HTTP/HTTPS, poor gRPC support
- **Limited policy**: Basic routing, but advanced policies require external services
- **Deprecated API**: Kubernetes Ingress API is feature-frozen and being replaced by Gateway API
- **NGINX Ingress Controller deprecation**: NGINX Ingress Controller is being deprecated in favor of Gateway API implementations
- **Limited observability**: Basic metrics, but not designed for distributed tracing
- **Complex configuration**: Advanced features require complex annotation syntax

## Decision

I adopted **Envoy Gateway** as my primary ingress solution, implementing the Kubernetes Gateway API specification.

**Key Components:**
- **Envoy Gateway**: Implements Gateway API, manages Envoy proxy data plane
- **Gateway API Resources**: `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute` (standard Kubernetes CRDs)
- **Policy Attachment**: Envoy-specific policies (rate limiting, circuit breaking) via ExtensionPolicy CRDs
- **TLS Management**: Integration with cert-manager for automated certificate issuance
- **DNS Integration**: External-DNS watches Gateway API resources for automatic DNS record creation

**Architecture:**
- Envoy Gateway controller runs in each cluster (local ingress for low latency)
- Gateway API resources define routing rules (declarative, GitOps-managed)
- Envoy proxy handles actual traffic forwarding
- Policies attached via ExtensionPolicy CRDs for advanced features
- TLS certificates managed by cert-manager (wildcard certs for efficiency)

**Deployment Model:**
- One Gateway instance per cluster (can have multiple Gateway resources)
- Gateway API resources are cluster-scoped, enabling centralized management
- Policies can be applied at Gateway, Route, or Backend level
- mTLS configured for east-west traffic (service-to-service)

## Consequences

### Positive

- **Standard API**: Gateway API is the future of Kubernetes ingress (Ingress is deprecated)
- **Vendor-agnostic**: Gateway API works with multiple implementations (future flexibility)
- **Rich protocol support**: HTTP, HTTPS, gRPC, TCP, UDP out of the box
- **Advanced policies**: Rate limiting, circuit breaking, retries, timeouts via ExtensionPolicy
- **Excellent observability**: Native OpenTelemetry integration, rich Envoy metrics
- **Security features**: mTLS, WAF, OAuth integration capabilities
- **Declarative configuration**: All routing defined in Kubernetes resources (GitOps-friendly)
- **Multi-cluster ready**: Gateway API designed for multi-cluster scenarios
- **gRPC native**: First-class support for gRPC routing and load balancing
- **Future-proof**: Aligned with Kubernetes direction (Gateway API is GA in 1.27+)

### Negative

- **Newer technology**: Less mature than NGINX Ingress (though Envoy itself is battle-tested)
- **Learning curve**: Requires learning Gateway API (different from Ingress)
- **Limited ecosystem**: Fewer third-party integrations than NGINX (though growing)
- **Resource overhead**: Envoy proxy is more resource-intensive than NGINX
- **Complexity**: More components (controller + data plane) than simple ingress controllers
- **Policy syntax**: ExtensionPolicy CRDs are Envoy-specific (though Gateway API is standard)

### Mitigations

- Comprehensive documentation in `docs/traffic-management.md`
- Examples in chart templates showing common patterns
- Keep NGINX Ingress Controller as optional fallback for legacy workloads
- Gradual migration (start with new services, migrate existing over time)
- Documentation and examples for Gateway API concepts

## Alternatives Considered

### 1. NGINX Ingress Controller
**Rejected because:**
- Uses deprecated Ingress API (not Gateway API)
- NGINX Ingress Controller itself is being deprecated in favor of Gateway API implementations
- Vendor-specific annotations create lock-in
- Limited gRPC support
- Advanced policies require external services (rate limiting, WAF)
- Not aligned with Kubernetes future direction

### 2. Traefik
**Rejected because:**
- Also uses Ingress API (though has Gateway API support in newer versions)
- Less mature Gateway API implementation than Envoy Gateway
- Smaller community than Envoy
- Less proven at enterprise scale

### 3. Istio Service Mesh
**Rejected because:**
- Overkill for ingress-only use case (full service mesh adds complexity)
- Higher resource overhead (control plane + data plane)
- More complex configuration
- I don't need full mesh capabilities (just ingress)

### 4. Cloud Load Balancers Only (GCP Load Balancer, AWS ALB)
**Rejected because:**
- Vendor lock-in (cloud-specific)
- Limited policy capabilities
- Higher cost at scale
- Less GitOps-friendly (requires cloud console/API)
- Can't use for east-west traffic

### 5. Kong Gateway
**Rejected because:**
- Proprietary features require enterprise license
- Less aligned with Gateway API standard
- Smaller community than Envoy
- More complex configuration model

## Implementation Notes

- Envoy Gateway deployed via Helm chart with Gateway API CRDs
- Sync wave `-2` ensures Gateway is ready before components that need ingress
- Wildcard certificates issued by cert-manager for efficiency
- External-DNS watches Gateway API resources (not just Ingress)
- ExtensionPolicy CRDs for Envoy-specific features (rate limiting, etc.)
- mTLS configured for secure service-to-service communication
- Grafana dashboards for Envoy metrics and tracing

## Migration Strategy

- New services use Gateway API from day one
- Existing services on NGINX Ingress should migrate to Gateway API (NGINX Ingress Controller is being deprecated)
- NGINX Ingress Controller remains available as temporary fallback during migration
- Prioritize migration to avoid future maintenance burden as NGINX Ingress Controller reaches end-of-life

## References

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- Repository: `charts/envoy-gateway/`
- Design doc: `docs/traffic-management.md`

