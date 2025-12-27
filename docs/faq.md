# Frequently Asked Questions (FAQ)

Common questions about the Platform in a Box, organized by topic.

## Table of Contents

- [General Questions](#general-questions)
- [Setup & Configuration](#setup--configuration)
- [Argo CD & GitOps](#argo-cd--gitops)
- [Components](#components)
- [Operations & Maintenance](#operations--maintenance)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## General Questions

### What is "Platform in a Box"?

Platform in a Box is a batteries-included, GitOps-driven foundation for operating a Kubernetes platform using the Argo CD App-of-Apps pattern. It provides a complete set of Helm charts that compose the core traffic, security, observability, data, and enablement layers so teams can onboard applications quickly with consistent guardrails.

### What Kubernetes version is required?

Kubernetes v1.27+ is required, primarily for Gateway API support (v1.27+ includes stable Gateway API CRDs). Some components may work with earlier versions, but v1.27+ is recommended.

### What's the difference between the ops cluster and workload clusters?

- **Ops Cluster**: The central command and control plane that hosts:
  - Argo CD control plane (orchestrates all deployments)
  - Centralized observability backends (Grafana, Thanos Global Query, Elasticsearch/Kibana, Jaeger Query)
  - Single RBAC and audit surface
  
- **Workload Clusters** (Dev, Stage, Prod): Execution targets that:
  - Run applications and platform components
  - Ship metrics/logs/traces back to ops cluster
  - Run local components (Envoy Gateway, Kyverno) for low latency and fail-closed posture

### Can I use this with a single cluster?

Yes, you can deploy everything to a single cluster. However, the architecture is designed for multi-cluster scenarios. For single cluster, you can:
- Deploy Argo CD and all components to the same cluster
- Skip multi-cluster federation (Thanos, centralized logging)
- Simplify the topology while keeping the same GitOps patterns

### What cloud providers are supported?

The platform is cloud-agnostic and works with any Kubernetes distribution. However, some components have cloud-specific integrations:
- **DNS**: Google Cloud DNS (default), but supports Route53, Cloudflare, Azure DNS, etc.
- **Object Storage**: GCS (default), but supports S3, Azure Blob, etc.
- **Load Balancers**: Works with any cloud provider's LoadBalancer service

---

## Setup & Configuration

### How do I add a new cluster?

1. **Create cluster values file**:
   ```bash
   cp charts/app-of-apps/values.ops-01.yaml charts/app-of-apps/values.new-cluster.yaml
   ```
   Edit and update cluster name, server endpoint, and component enablement.

2. **Create bootstrap file**:
   ```bash
   cp argocd-bootstrap-apps/ops-01.yaml argocd-bootstrap-apps/new-cluster.yaml
   ```
   Update application name, cluster server, and values file reference.

3. **Register cluster in Argo CD**:
   ```bash
   argocd cluster add <cluster-context> --name <cluster-name>
   ```

4. **Apply bootstrap**:
   ```bash
   kubectl apply -f argocd-bootstrap-apps/new-cluster.yaml
   ```

See [Getting Started Guide](getting-started.md#step-8-configure-additional-clusters) for detailed steps.

### How do I update a component version?

Update the `source.targetRevision` in the component's block in your values file:

```yaml
monitoring:
  enable: true
  source:
    targetRevision: v1.2.3  # or branch name, commit SHA
```

Or update the chart dependency version in the component's `Chart.yaml` if using a Helm dependency.

### How do I enable/disable a component?

Edit the environment values file (e.g., `charts/app-of-apps/values.ops-01.yaml`):

```yaml
# Enable a component
monitoring:
  enable: true

# Disable a component
redis:
  enable: false
```

After committing and pushing, Argo CD will automatically sync the changes.

### How do I customize component configuration?

Each component has its own values file structure. Override settings in the environment-specific values file:

```yaml
monitoring:
  enable: true
  helm:
    values: |
      prometheus:
        replicaCount: 3
      thanos:
        enabled: true
```

Or create a separate values file and reference it:

```yaml
monitoring:
  enable: true
  helm:
    valueFiles:
      - values.monitoring-custom.yaml
```

### What's the difference between `targetRevision: HEAD`, `staging`, and `stable`?

- **`HEAD`** (or `master`/`dev`): Latest commits on the branch - use for development clusters
- **`staging`**: Staging branch - use for pre-production testing
- **`stable`**: Immutable tag - use for production clusters

This follows the [Branching & Promotion Model](../README.md#branching--promotion-model).

---

## Argo CD & GitOps

### How does the App-of-Apps pattern work?

The App-of-Apps pattern uses a root Argo CD Application that manages other Applications. In this platform:

1. Bootstrap Application (`ops-01-bootstrap-apps`) points to the `app-of-apps` chart
2. The `app-of-apps` chart renders multiple Argo CD `Application` CRs (one per enabled component)
3. Each child Application manages its component's Helm chart
4. All orchestrated from a single root, enabling consistent deployment across clusters

### How do I sync applications manually?

```bash
# Sync a specific application
argocd app sync <app-name>

# Sync all applications
argocd app sync --all

# Force refresh (clears cache)
argocd app get <app-name> --hard-refresh
```

### What are sync waves and why do I need them?

Sync waves control the order in which Argo CD syncs applications. Lower numbers sync first. This ensures dependencies are ready before dependents:

```yaml
sealedSecrets:
  enable: true
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Syncs first
certManager:
  enable: true
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # Syncs after sealed-secrets
envoyGateway:
  enable: true
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Syncs after cert-manager
```

See [Traffic Management Guide](traffic-management.md#suggested-sync-waves) for recommended sync waves.

### How do I rollback a deployment?

Since everything is Git-driven, rollback by reverting the Git commit or moving the tag:

```bash
# Revert commit
git revert <commit-sha>
git push

# Or move stable tag to previous commit
git tag -f stable <previous-commit-sha>
git push -f origin stable
```

Argo CD will automatically detect the change and sync to the previous state.

### Can I use a different Git repository?

Yes, update the `source.repoURL` in:
- Bootstrap files: `argocd-bootstrap-apps/*.yaml`
- Values files: `charts/app-of-apps/values.*.yaml`

Ensure Argo CD has access to the repository (SSH key or HTTPS credentials).

---

## Components

### How do I rotate sealed secrets keys?

1. **Generate new key pair**:
   ```bash
   openssl req -x509 -days 3650 -nodes -newkey rsa:4096 \
     -keyout new-sealing.key \
     -out new-sealing.crt \
     -subj "/CN=sealed-secret/O=sealed-secret"
   ```

2. **Create new secret in cluster**:
   ```bash
   kubectl -n sealed-secrets create secret tls new-sealing-key \
     --cert=new-sealing.crt --key=new-sealing.key
   ```

3. **Label as active**:
   ```bash
   kubectl -n sealed-secrets label secret new-sealing-key \
     sealedsecrets.bitnami.com/sealed-secrets-key=active
   ```

4. **Remove label from old key**:
   ```bash
   kubectl -n sealed-secrets label secret old-sealing-key \
     sealedsecrets.bitnami.com/sealed-secrets-key-
   ```

5. **Reseal existing secrets** (if needed):
   ```bash
   kubeseal --cert=new-sealing.crt < secret.yaml > sealed-secret.yaml
   ```

See [Sealed Secrets README](../charts/sealed-secrets/README.md#providing-a-userdefined-sealing-key-recommended) for details.

### How do I add a new domain for certificate issuance?

1. **Create DNS zone** (in your DNS provider)

2. **Update cert-manager values** to include new domain:
   ```yaml
   issuers:
     newDomain: "enable"
   ```

3. **Create ClusterIssuer template** (if needed) in `charts/cert-manager/templates/certificates/`

4. **Create Certificate CR** for the domain:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: Certificate
   metadata:
     name: newdomain-com
   spec:
     dnsNames:
       - "*.newdomain.com"
       - "newdomain.com"
     issuerRef:
       kind: ClusterIssuer
       name: newdomain-com-issuer
     secretName: newdomain-com-tls
   ```

5. **Update external-dns domain filters** to include new domain

See [Traffic Management Guide](traffic-management.md) for details.

### How do I expose a service via Envoy Gateway?

1. **Create HTTPRoute**:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: my-service
   spec:
     parentRefs:
       - name: envoy-public
         namespace: envoy-gateway-system
     hostnames:
       - my-service.example.com
     rules:
       - matches:
           - path:
               type: PathPrefix
               value: /
         backendRefs:
           - name: my-service
             port: 80
   ```

2. **Ensure Gateway exists** (created by `envoy-gateway` chart)

3. **Ensure certificate exists** for the hostname

4. **Annotate for DNS** (if using external-dns):
   ```yaml
   metadata:
     annotations:
       external-dns.alpha.kubernetes.io/hostname: my-service.example.com
   ```

See [Envoy Gateway README](../charts/envoy-gateway/README.md) for details.

### What's the difference between Audit and Enforce mode in Kyverno?

- **Audit Mode**: Policies log violations but don't block resources. Use this initially to measure compliance.
- **Enforce Mode**: Policies block non-compliant resources at admission time. Enable after achieving low violation rates in Audit mode.

Always start with Audit mode, measure violations, remediate, then enable Enforce mode. See [Compliance Guide](compliance.md#progressive-rollout-strategy-audit--enforce-ladder).

### How do I add a new Kyverno policy?

1. **Create policy file** in `charts/kyverno/templates/policies/ops/` or `security/`

2. **Wrap with values conditional**:
   ```yaml
   {{- if .Values.opsPolicies.newPolicy.enabled }}
   apiVersion: kyverno.io/v1
   kind: ClusterPolicy
   ...
   {{- end }}
   ```

3. **Add to values file**:
   ```yaml
   opsPolicies:
     newPolicy:
       enabled: true
       mode: Audit  # Start with Audit
   ```

4. **Document rationale** in policy annotations

See [Kyverno README](../charts/kyverno/README.md#adding-new-policies) for details.

### How do I add a new Prometheus alert rule?

1. **Create or edit rule file** in `charts/monitoring/configs/alert-rules/`

2. **Update [Alert Catalog](alert-catalog.md)** with the new alert

3. **Test the rule**:
   ```bash
   promtool check rules configs/alert-rules/my-alerts.yaml
   ```

---

## Operations & Maintenance

### How often should I update components?

- **Development clusters**: Update frequently (track `HEAD` or `dev` branch)
- **Staging clusters**: Update after validation in dev (track `staging` branch)
- **Production clusters**: Update only after thorough testing (track `stable` tag)

Follow the [Promotion Flow](../README.md#promotion-flow): dev → staging → stable.

### How do I backup the platform configuration?

Everything is in Git, so your Git repository is the backup. Additionally:

- **Sealed Secrets keys**: Backup the private key securely (encrypted storage, KMS)
- **Argo CD cluster secrets**: Backup cluster registration secrets
- **Object storage data**: Configure lifecycle policies and backups per your requirements

### How do I scale components?

Update replica counts in component values:

```yaml
monitoring:
  enable: true
  helm:
    values: |
      prometheus:
        replicaCount: 3  # Scale Prometheus
```

Or scale directly (not recommended, will be overridden by GitOps):
```bash
kubectl scale deployment <deployment> -n <namespace> --replicas=3
```

### How do I check platform health?

```bash
# Check all Argo CD applications
kubectl get applications -n argocd

# Check component pods
kubectl get pods -A | grep -E "monitoring|logging|envoy|kyverno"

# Check via Argo CD UI
# Navigate to Argo CD and review application health status
```

### How do I add a new environment (e.g., QA)?

1. **Create values file**: `charts/app-of-apps/values.qa-01.yaml`
2. **Create bootstrap file**: `argocd-bootstrap-apps/qa-01.yaml`
3. **Register cluster** in Argo CD
4. **Apply bootstrap**: `kubectl apply -f argocd-bootstrap-apps/qa-01.yaml`

Follow the same pattern as existing environments.

### How do I migrate from traditional Helm to this GitOps approach?

1. **Export existing Helm releases**:
   ```bash
   helm list -A
   helm get values <release> -n <namespace> > values.yaml
   ```

2. **Create equivalent values files** in this repository structure

3. **Disable old Helm releases** (don't delete yet)

4. **Bootstrap Argo CD** and let it take over

5. **Verify everything works**, then remove old Helm releases

See [Getting Started Guide](getting-started.md) for the GitOps setup process.

---

## Troubleshooting

### Why is my application stuck in "Syncing" state?

Common causes:
- Repository authentication issues
- Helm dependency not updated
- Resource conflicts
- Sync wave ordering issues

See [Troubleshooting Guide](troubleshooting.md#application-stuck-in-syncing-state) for detailed diagnosis.

### Why are certificates not issuing?

Common causes:
- DNS provider credentials incorrect
- DNS propagation delays
- ACME rate limits
- ClusterIssuer not configured

See [Troubleshooting Guide](troubleshooting.md#certificate-not-issuing) for diagnosis steps.

### Why are DNS records not being created?

Common causes:
- External-dns credentials incorrect
- Domain filter mismatch
- Insufficient IAM permissions
- Missing annotations on services/routes

See [Troubleshooting Guide](troubleshooting.md#dns-records-not-created) for solutions.

### Why is Prometheus not scraping my service?

Common causes:
- ServiceMonitor not created
- Service annotations missing
- Network policies blocking
- Service has no endpoints

See [Troubleshooting Guide](troubleshooting.md#prometheus-not-scraping-targets) for diagnosis.

### Why is Elasticsearch cluster status RED?

Common causes:
- Insufficient nodes
- Disk space full
- Shard allocation issues
- Node failures

See [Troubleshooting Guide](troubleshooting.md#elasticsearch-cluster-not-healthy) for solutions.

### How do I debug Argo CD sync issues?

```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force refresh
argocd app get <app-name> --hard-refresh
```

See [Troubleshooting Guide](troubleshooting.md#argo-cd-issues) for comprehensive debugging steps.

---

## Best Practices

### Should I use sealed secrets or external secrets operator?

This platform uses **Sealed Secrets** because:
- Secrets are encrypted and can be committed to Git
- No external service dependencies
- Works well with GitOps workflows
- Simple key rotation

External Secrets Operator is an alternative if you prefer cloud-native secret management (AWS Secrets Manager, HashiCorp Vault, etc.).

### Should I use Gateway API or Ingress?

**Use Gateway API** (Envoy Gateway) for:
- New services and applications
- Modern routing features
- Better policy attachment
- Multi-cluster consistency

**Use Ingress** (NGINX) only for:
- Legacy applications that require it
- Temporary migration period

The platform includes both, but Gateway API is preferred.

### How should I organize my Git repository?

Recommended structure:
```
k8s/
├── charts/              # Helm charts
│   ├── app-of-apps/
│   ├── monitoring/
│   └── ...
├── argocd-bootstrap-apps/  # Bootstrap applications
├── docs/                # Documentation
└── README.md
```

Keep environment-specific values in `charts/<chart>/values.<env>.yaml`.

### Should I use tags or branches for production?

**Use tags** (`stable`) for production because:
- Immutable references
- Clear provenance
- Easy rollback
- Audit trail

Branches can move, making it harder to track what's deployed. Tags provide deterministic deployments.

### How do I handle secrets for multiple clusters?

Options:
1. **Same key, different scopes**: Use namespace-scoped sealed secrets
2. **Different keys per cluster**: Generate cluster-specific sealing keys
3. **Centralized key with cluster labels**: Use cluster-wide scope with cluster-specific labels

Recommendation: Use cluster-specific keys for better isolation and security.

### Should I enable all components in all clusters?

No. Enable components based on cluster role:

- **Ops Cluster**: All components (control plane + observability backends)
- **Workload Clusters**: 
  - Local components: Envoy Gateway, Kyverno, monitoring (Prometheus)
  - Remote components: Logging (Filebeat only), Jaeger (collectors only)
  - Optional: Redis, other data services

See [What Runs Where](../charts/app-of-apps/what-runs-where.md) for the component matrix.

### How do I handle certificate renewal?

Cert-manager handles automatic renewal. However:

- **Monitor expiration**: Set up alerts for certificates expiring soon
- **Test renewal**: Use staging issuer first
- **Force renewal**: `kubectl annotate certificate <name> cert-manager.io/issue-temporary-certificate=true`

Certificates are automatically renewed 30 days before expiration.

### How do I ensure high availability?

- **Argo CD**: Run in HA mode (2+ replicas for controllers, repo-server, server)
- **Prometheus**: Use 2+ replicas with anti-affinity
- **Elasticsearch**: Use 3+ master nodes, multiple data nodes
- **Envoy Gateway**: Use 2+ replicas with PDB
- **Use node anti-affinity**: Spread pods across nodes/zones

See [Argo CD Best Practices](argocd-best-practices.md#2-always-deploy-argocd-in-ha) for HA configuration.

### How do I monitor the platform itself?

The monitoring stack monitors itself:

- **Argo CD metrics**: Scraped by Prometheus (if annotations added)
- **Component metrics**: Each component exposes Prometheus metrics
- **Platform alerts**: Use the [Alert Catalog](alert-catalog.md) alerts
- **Grafana dashboards**: Pre-configured dashboards for components

Set up alerts for:
- Application sync failures
- Component pod restarts
- Certificate expiration
- Resource usage thresholds

---

## Still Have Questions?

- Check the [Troubleshooting Guide](troubleshooting.md) for specific issues
- Review component-specific READMEs in `charts/<component>/README.md`
- See detailed architecture docs in `docs/`
- Review the [Main README](../README.md) for platform overview

If you're stuck or need further help, feel free to reach out directly.

