# Envoy Gateway Best Practices

This document outlines best practices for using Envoy Gateway in production environments, covering architecture patterns, certificate management, observability, and operational considerations.

## Table of Contents

- [Gateway Architecture Patterns](#gateway-architecture-patterns)
- [Certificate Management](#certificate-management)
- [HTTP to HTTPS Redirect](#http-to-https-redirect)
- [Observability & Monitoring](#observability--monitoring)
- [Route Management Strategy](#route-management-strategy)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

## Gateway Architecture Patterns

### Shared Gateways vs. Dedicated Gateways

When migrating from NGINX Ingress or designing a new platform, consider using **shared Gateways** rather than creating dedicated Gateways per application.

**Benefits of Shared Gateways:**
- **Simplified management**: Single Gateway resource to manage per cluster/environment
- **Consistent TLS configuration**: All routes inherit the same certificate and TLS settings
- **Reduced resource overhead**: One Gateway instance handles multiple routes
- **Easier DNS management**: Single DNS entry per Gateway
- **Centralized policy application**: Apply rate limiting, WAF, and other policies at Gateway level

**When to Use Dedicated Gateways:**
- Different TLS requirements per application
- Isolation requirements (separate Gateway for sensitive workloads)
- Different listener configurations (ports, protocols)

### Merged Gateways

Envoy Gateway supports **Merged Gateways** when different Gateway resources are needed but a single network load balancer will service all of them. This is useful when:
- Multiple teams need separate Gateway resources for organizational boundaries
- Different Gateway configurations are required but share the same infrastructure
- You want to maintain separation while optimizing resource usage

With Merged Gateways, Envoy Gateway merges multiple Gateway resources into a single Envoy proxy instance, reducing resource overhead while maintaining logical separation.

**Recommended Pattern:**
```yaml
# One Gateway per environment/cluster
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gateway
  namespace: envoy-gateway-system
spec:
  gatewayClassName: envoy
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-cert
            namespace: envoy-gateway-system
```

Applications then reference this Gateway via `parentRefs` in their HTTPRoute resources.

## Certificate Management

### Prefer Certificate CRs Over Annotations

While cert-manager supports inline annotations on Gateway resources, **prefer using Certificate Custom Resources** for better lifecycle management.

**Why Certificate CRs:**
- **Better observability**: Certificate status conditions show issuance progress
- **Clearer Git diffs**: Certificate resources are explicit and version-controlled
- **Easier troubleshooting**: Certificate events and status are visible in kubectl
- **Renewal visibility**: Certificate renewal windows and status are trackable

**Pattern:**
```yaml
# 1. Create Certificate CR
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-example-com
  namespace: envoy-gateway-system
spec:
  secretName: wildcard-example-com-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.example.com"
    - "example.com"

# 2. Reference in Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
spec:
  listeners:
    - name: https
      tls:
        certificateRefs:
          - name: wildcard-example-com-tls  # References the secret created by Certificate CR
            namespace: envoy-gateway-system
```

### Certificate Replication with Reflector

When certificates need to be available in multiple namespaces, use [kubernetes-reflector](https://github.com/emberstack/kubernetes-reflector) to replicate secrets across namespaces.

Reflector is a Kubernetes controller that can replicate secrets, configmaps, and certificates to multiple namespaces. This avoids creating multiple Certificate CRs and ensures all namespaces use the same certificate.

For detailed usage and configuration, see the [kubernetes-reflector documentation](https://github.com/emberstack/kubernetes-reflector).

## HTTP to HTTPS Redirect

### Enforce HTTPS by Default

All HTTP traffic should be redirected to HTTPS for security. Configure this at the Gateway level:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gateway
spec:
  listeners:
    - name: http
      protocol: HTTP
      port: 80
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: wildcard-cert
```

Then create an HTTPRoute that redirects all HTTP traffic to HTTPS (no hostname restriction):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: http-to-https-redirect
spec:
  parentRefs:
    - name: shared-gateway
      sectionName: http
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            scheme: https
            statusCode: 301
```

This redirects all HTTP traffic to HTTPS regardless of hostname.

**Alternative:** Use Envoy Gateway's built-in redirect capability if available in your version.

## Observability & Monitoring

### Prometheus Service Discovery Limitation

**Important:** Prometheus does not natively recognize Gateway API route resources (HTTPRoute, GRPCRoute) for service discovery. This affects tools like Blackbox Exporter that rely on Prometheus service discovery.

**Solution: Annotate Services Instead**

For Blackbox Exporter to discover endpoints, annotate the **Service resources** that back your routes:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/blackbox: "true"
    prometheus.io/blackbox-module: "http_2xx"
    prometheus.io/path: "/health"
    prometheus.io/port: "8080"
spec:
  ports:
    - port: 8080
      targetPort: 8080
```

Blackbox Exporter will discover these annotated services and probe them, regardless of whether they're exposed via Gateway API or traditional Ingress.

**Best Practice:**
- Add annotations to Services in application charts
- Use consistent annotation patterns for auto-discovery
- Document annotation requirements in application chart READMEs

### Metrics and Tracing

- **Envoy metrics**: Exposed on the Envoy Gateway service (port 19000 by default)
- **Custom Resource Monitoring**: Configure kube-state-metrics custom resource state monitoring for Gateway API resources (Gateway, HTTPRoute, GRPCRoute) to track resource state and status
- **Distributed tracing**: Configure OpenTelemetry in Envoy Gateway for request tracing

## Route Management Strategy

### Separation of Concerns

**Current Pattern:**
- **Gateway resources**: Managed in `envoy-gateway` chart (platform team)
- **HTTPRoute/GRPCRoute resources**: Managed in application charts (application teams)

**Challenge:**
Adding specific listeners or Gateway configurations for a service requires changes to both:
1. The `envoy-gateway` chart (to add listener)
2. The application chart (to create route)

This creates coordination overhead and potential conflicts.

### Future: ListenerSet Functionality

**ListenerSet** (coming soon, see [GEP-1713](https://gateway-api.sigs.k8s.io/geps/gep-1713/)) will allow application teams to define listeners without modifying the Gateway resource.

For the complete specification and YAML examples, see [GEP-1713: ListenerSet](https://gateway-api.sigs.k8s.io/geps/gep-1713/#yaml).

**Current Workaround:**
- Use shared Gateway with standard listeners (80, 443)
- Route differentiation via hostnames and paths
- For special requirements, coordinate Gateway changes through platform team

**Best Practice:**
- Prefer hostname/path-based routing over custom listeners
- Document any custom listener requirements
- Plan for ListenerSet adoption when available

## Security Considerations

### TLS Configuration

- **TLS 1.2 minimum**: Configure minimum TLS version
- **Strong cipher suites**: Use modern cipher suites only
- **Certificate rotation**: Ensure certificates auto-renew via cert-manager
- **mTLS for east-west**: Configure mTLS for service-to-service communication

### Rate Limiting

Apply rate limiting at Gateway or Route level using ExtensionPolicy:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ExtensionPolicy
metadata:
  name: rate-limit-policy
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: my-app-route
  rateLimit:
    rules:
      - limit:
          requests: 100
          unit: Minute
```

### Network Policies

- Restrict Gateway access to only necessary namespaces
- Use NetworkPolicies to limit east-west traffic
- Isolate Gateway control plane from workloads

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Route not accessible | Gateway not ready | Check Gateway status: `kubectl get gateway` |
| TLS handshake fails | Certificate not issued | Check Certificate CR status: `kubectl get certificate` |
| 404 errors | Hostname mismatch | Verify HTTPRoute hostnames match Gateway hostname |
| DNS not resolving | External-DNS not syncing | Check external-dns logs and Gateway annotations |
| Metrics missing | Service not annotated | Add Prometheus annotations to Service resources |

### Debugging Commands

```bash
# Check Gateway status
kubectl get gateway -A

# Check HTTPRoute status
kubectl get httproute -A

# View Envoy configuration
kubectl exec -n envoy-gateway-system <envoy-pod> -- curl localhost:19000/config_dump

# Check certificate status
kubectl get certificate -A

# View Gateway API events
kubectl get events --field-selector involvedObject.kind=Gateway
```

## References

- [Kubernetes Gateway API Specification](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Traffic Management Guide](traffic-management.md) - Platform-specific traffic management patterns
- Repository: `charts/envoy-gateway/`

