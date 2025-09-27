# Argo CD Best Practices

## 1. Custom Resource Tracking Label
Set a custom label key to improve multi-tenancy and avoid collisions:

```
application.instanceLabelKey: argocd.argoproj.io/instance
```

Add this under `data` in the `argocd-cm` ConfigMap (e.g. `argocd-cm.yaml`). After updating, restart the Argo CD application controller/statefulset if not auto-rolling.

## 2. Always Deploy Argo CD in HA
Run Argo CD in High Availability mode for production:
- At least 2 replicas for `argocd-repo-server`, `argocd-application-controller`, `argocd-server`
- Use Redis HA (sentinel) or an external managed Redis
- Enable sharding if you manage many applications (controller sharding via labels)
- Use persistent storage for the repository server cache if needed for performance
- Set replica awareness env vars so components self-report correct topology:
  - `ARGOCD_CONTROLLER_REPLICAS` in the application controller pod spec (must match its replica count)
  - `ARGOCD_API_SERVER_REPLICAS` in the argocd-server deployment (must match server replica count)

Example (controller excerpt):
```yaml
env:
  - name: ARGOCD_CONTROLLER_REPLICAS
    value: "4"
```
Example (server excerpt):
```yaml
env:
  - name: ARGOCD_API_SERVER_REPLICAS
    value: "4"
```

## 3. Enabling Redis Dangerous Commands (Drop/Delete)
By default, Redis "dangerous" commands (like FLUSH*, CONFIG, SHUTDOWN) are disabled in the Argo CD Redis HA chart for safety.
If you need to enable drop DB–related commands, edit the `redis.conf` in the `argocd-redis-ha-configmap` and remove or adjust the `rename-command` or `disable-commands` directives accordingly. Apply the change and restart the Redis pods. Only do this if you fully understand the operational and security impact.

## 4. Exposing Argo CD via Kubernetes Gateway API
You can expose the Argo CD UI (and API) using Envoy Gateway + Gateway API with TLS backend validation using the following manifest:

```yaml
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: argocd-backend-tls
  namespace: argocd
spec:
  targetRefs:
    - group: ""
      kind: Service
      name: argocd-server
      sectionName: https
  validation:
    wellKnownCACertificates: "System"
    hostname: argocd.mydomain.com
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: argocd
  namespace: argocd
spec:
  parentRefs:
    - name: eg-infra-01
      namespace: envoy-gateway-system
      sectionName: https
  hostnames:
    - argocd.mydomain.com
  rules:
    - backendRefs:
        - name: argocd-server
          port: 443
      matches:
        - path:
            type: PathPrefix
            value: "/"
      timeouts:
        request: "180s"
```

Apply with:
```
kubectl apply -f argocd-httproute.yaml
```

## 5. Additional Recommendations
- Enforce RBAC least privilege via `argocd-rbac-cm.yaml`
- Use SSO (OIDC / SAML) instead of local accounts
- Scan and pin Argo CD image versions; avoid :latest
- Enable notifications & auditing
- Backup repositories and Redis data (if persistent)
- Use project-scoped repo / cluster / namespace restrictions
- Prefer ApplicationSets for large-scale automation

## 6. Air-Gapped / Restricted Network Clusters
Use Argo CD Agent mode for disconnected or hub-and-spoke environments. See official documentation for installation and operations guidance:

https://argocd-agent.readthedocs.io/latest/

Key benefits:
- Pull-based (no inbound connectivity required)
- Reduced credential exposure
- Scales multi-cluster management

## 7. Metrics Scraping
Expose Argo CD metrics to Prometheus:

Add annotations to the `argocd-server` Service for the API/server metrics (port 8082):
```yaml
metadata:
  annotations:
    prometheus.io/port: "8082"
    prometheus.io/scrape: "true"
```
If you run a dedicated metrics service (e.g. `argocd-server-metrics` listening on 8083), annotate it similarly:
```yaml
metadata:
  annotations:
    prometheus.io/port: "8083"
    prometheus.io/scrape: "true"
```
Prefer ServiceMonitor (Prometheus Operator) when available instead of raw annotations:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  namespaceSelector:
    matchNames:
      - argocd
  endpoints:
    - port: metrics
      interval: 30s
```
Key metrics to watch:
- Reconciliation performance: `argocd_app_reconcile_*`
- Health / sync status: `argocd_app_info`, `argocd_app_sync_total`
- Controller queue: `argocd_app_k8s_request_total`
- API latency: `argocd_api_server_request_duration_seconds`

---


