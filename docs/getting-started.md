# Getting Started Guide

This guide walks you through setting up the Platform in a Box from scratch. It assumes you have a Kubernetes cluster ready and Argo CD installed in your ops cluster.

## Prerequisites Checklist

Before starting, ensure you have:

### Infrastructure
- [ ] Kubernetes cluster (v1.27+) with admin access
- [ ] Argo CD installed in the ops cluster (namespace: `argocd`)
- [ ] Object storage bucket (GCS/S3) for Thanos metrics (if enabling monitoring)
- [ ] DNS provider configured (Google Cloud DNS, Route53, etc.) with API access
- [ ] Load balancer support for Gateway API

### Tools
- [ ] `kubectl` v1.27+ configured with cluster access
- [ ] `helm` v3.8+ installed
- [ ] `kubeseal` CLI installed (for sealed secrets)
- [ ] `yq` v4+ installed (for value file manipulation)
- [ ] Git access to the repository

### Credentials & Secrets
- [ ] DNS provider service account credentials (for cert-manager and external-dns)
- [ ] Object storage service account credentials (for Thanos, if enabling monitoring)
- [ ] Sealed Secrets controller key pair (or plan to generate one)
- [ ] ACME-compatible certificate authority access (Let's Encrypt recommended)

### Knowledge
- [ ] Basic understanding of Kubernetes concepts
- [ ] Familiarity with Helm charts
- [ ] Understanding of GitOps principles
- [ ] Knowledge of Argo CD basics

## Step 1: Clone and Prepare Repository

```bash
# Clone the repository
git clone <your-repo-url>
cd k8s

# Verify structure
ls -la charts/
ls -la argocd-bootstrap-apps/
```

## Step 2: Configure Environment Values

Each environment has its own values file. Start with the ops cluster configuration:

```bash
# Review the ops cluster values
cat charts/app-of-apps/values.ops-01.yaml
```

### Key Configuration Areas

1. **Cluster Configuration**:
   ```yaml
   cluster:
     name: ops-01
     server: https://ops-cluster.example.com
   ```

2. **Source Configuration**:
   ```yaml
   source:
     repoURL: git@github.com:YourOrg/k8s.git
     targetRevision: stable  # or HEAD for dev
   ```

3. **Component Enablement**:
   ```yaml
   sealedSecrets:
     enable: true
   certManager:
     enable: true
   envoyGateway:
     enable: true
   monitoring:
     enable: true
   logging:
     enable: true
   ```

### Update Required Values

Edit `charts/app-of-apps/values.ops-01.yaml` and update:
- Cluster name and server endpoint
- Repository URL
- Target revision (branch/tag)
- Component enablement flags
- Domain names for your environment
- Namespace preferences

## Step 3: Prepare Sealed Secrets

Sealed Secrets allow you to commit encrypted secrets to Git. You'll need to seal credentials before deployment.

### 3.1 Generate or Obtain Sealing Key

If you don't have a sealing key yet:

```bash
# Option 1: Generate new key pair
mkdir -p sealing-key && cd sealing-key
openssl req -x509 -days 3650 -nodes -newkey rsa:4096 \
  -keyout platform-sealing.key \
  -out platform-sealing.crt \
  -subj "/CN=sealed-secret/O=sealed-secret"

# Option 2: Fetch public cert from existing controller
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  > pub-cert.pem
```

**Important**: Store the private key (`platform-sealing.key`) securely. Without it, you cannot decrypt existing sealed secrets.

### 3.2 Seal Required Secrets

Create and seal secrets for:

**DNS Provider Credentials** (for cert-manager and external-dns):
```bash
# Create secret manifest (DO NOT COMMIT THIS)
cat > dns-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: clouddns-dns01-solver-svc-acct
  namespace: cert-manager
type: Opaque
stringData:
  key.json: |
    {
      "type": "service_account",
      "project_id": "your-project",
      ...
    }
EOF

# Seal it
kubeseal --cert=pub-cert.pem --scope=namespace-wide \
  --namespace=cert-manager \
  --format=yaml < dns-credentials.yaml > sealed-dns-credentials.yaml

# Clean up unsealed file
rm dns-credentials.yaml
```

**Object Storage Credentials** (for Thanos, if enabling monitoring):
```bash
# Create secret for GCS
cat > thanos-gcs-credentials.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: thanos-gcs-credentials
  namespace: monitoring
type: Opaque
stringData:
  thanos.yaml: |
    type: GCS
    config:
      bucket: thanos-ops-01
      service_account: |
        {
          "type": "service_account",
          ...
        }
EOF

# Seal it
kubeseal --cert=pub-cert.pem --scope=namespace-wide \
  --namespace=monitoring \
  --format=yaml < thanos-gcs-credentials.yaml > sealed-thanos-gcs.yaml

rm thanos-gcs-credentials.yaml
```

**Elasticsearch Credentials** (for logging, if enabling):
```bash
# Similar process for ES credentials
# See charts/logging/README.md for details
```

### 3.3 Commit Sealed Secrets

Add sealed secrets to the appropriate chart directories:

```bash
# DNS credentials go to cert-manager or external-dns chart
# Object storage goes to monitoring chart
# ES credentials go to logging/jaeger charts

git add charts/*/sealed-*.yaml
git commit -m "Add sealed secrets for ops-01"
```

## Step 4: Configure Bootstrap Application

The bootstrap application is the entry point that creates the App-of-Apps root.

### 4.1 Review Bootstrap File

```bash
cat argocd-bootstrap-apps/ops-01.yaml
```

### 4.2 Update Bootstrap Configuration

Edit `argocd-bootstrap-apps/ops-01.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ops-01-bootstrap-apps
  namespace: argocd
spec:
  project: operations
  source:
    repoURL: git@github.com:YourOrg/k8s.git  # Update this
    path: charts/app-of-apps
    targetRevision: stable  # or HEAD for initial dev setup
    helm:
      valueFiles:
        - values.ops-01.yaml
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      selfHeal: true
      allowEmpty: true
      prune: true
```

### 4.3 Commit Bootstrap File

```bash
git add argocd-bootstrap-apps/ops-01.yaml
git commit -m "Configure ops-01 bootstrap application"
git push
```

## Step 5: Bootstrap Argo CD Application

Apply the bootstrap application to your ops cluster:

```bash
# Ensure you're connected to the ops cluster
kubectl cluster-info

# Apply the bootstrap application
kubectl apply -f argocd-bootstrap-apps/ops-01.yaml

# Verify it was created
kubectl get application -n argocd ops-01-bootstrap-apps
```

## Step 6: Verify Initial Sync

Wait for Argo CD to sync the bootstrap application:

```bash
# Watch application status
kubectl get application -n argocd ops-01-bootstrap-apps -w

# Or check via Argo CD CLI
argocd app get ops-01-bootstrap-apps

# Or use Argo CD UI
# Navigate to: https://argocd.your-domain.com
```

### Expected Behavior

1. Bootstrap application appears in Argo CD
2. App-of-Apps chart renders child Applications
3. Child Applications start syncing (may take 5-10 minutes)
4. Components deploy in order (sealed-secrets first, then cert-manager, etc.)

### Check Component Status

```bash
# List all applications
kubectl get applications -n argocd

# Check specific component
kubectl get application -n argocd ops-01-sealed-secrets
kubectl get application -n argocd ops-01-cert-manager
kubectl get application -n argocd ops-01-envoy-gateway
```

## Step 7: Verify Component Health

Once components are synced, verify they're running:

### Sealed Secrets
```bash
kubectl get pods -n sealed-secrets
kubectl get sealedsecrets -A
```

### Cert Manager
```bash
kubectl get pods -n cert-manager
kubectl get clusterissuers
```

### Envoy Gateway
```bash
kubectl get pods -n envoy-gateway-system
kubectl get gateways -A
```

### Monitoring (if enabled)
```bash
kubectl get pods -n monitoring
kubectl get prometheus -n monitoring
```

### Logging (if enabled)
```bash
kubectl get pods -n logging
kubectl get elasticsearch -n logging
```

## Step 8: Configure Additional Clusters

To add workload clusters (dev, staging, prod):

### 8.1 Create Cluster Values File

```bash
cp charts/app-of-apps/values.ops-01.yaml charts/app-of-apps/values.dev-01.yaml
```

Edit `values.dev-01.yaml`:
- Update cluster name and server endpoint
- Set `targetRevision: HEAD` or `dev` for development
- Adjust component enablement as needed

### 8.2 Create Bootstrap File

```bash
cp argocd-bootstrap-apps/ops-01.yaml argocd-bootstrap-apps/dev-01.yaml
```

Edit `dev-01.yaml`:
- Update application name
- Update cluster server endpoint
- Point to `values.dev-01.yaml`

### 8.3 Register Cluster in Argo CD

```bash
# Get cluster kubeconfig
kubectl config view --minify --raw > dev-cluster-kubeconfig.yaml

# Register in Argo CD
argocd cluster add dev-cluster-context \
  --kubeconfig dev-cluster-kubeconfig.yaml \
  --name dev-01 \
  --server https://dev-cluster.example.com

# Or manually create cluster secret
kubectl create secret generic dev-01-cluster \
  --from-file=config=dev-cluster-kubeconfig.yaml \
  -n argocd \
  --type=Opaque
kubectl label secret dev-01-cluster -n argocd argocd.argoproj.io/secret-type=cluster
```

### 8.4 Apply Bootstrap

```bash
kubectl apply -f argocd-bootstrap-apps/dev-01.yaml
```

## Step 9: Validate End-to-End

### Test Certificate Issuance

```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Verify DNS challenge
dig _acme-challenge.your-domain.com TXT
```

### Test DNS Automation

```bash
# Create a test HTTPRoute
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: test-route
spec:
  hostnames:
    - test.your-domain.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: test-service
          port: 80
EOF

# Check DNS record was created
dig test.your-domain.com
```

### Test Observability (if enabled)

```bash
# Access Grafana (if exposed)
curl https://grafana.your-domain.com

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Elasticsearch health
kubectl port-forward -n logging svc/elasticsearch-es-http 9200:9200
curl -u elastic:password https://localhost:9200/_cluster/health
```

## Step 10: Next Steps

### Enable Additional Components

Edit your values file to enable more components:

```yaml
kyverno:
  enable: true
redis:
  enable: true
jaeger:
  enable: true
```

### Configure Monitoring Alerts

- Review [Alert Catalog](../docs/alert-catalog.md)
- Customize alert rules in `charts/monitoring/configs/alert-rules/`
- Configure Alertmanager receivers

### Set Up Policy Enforcement

- Start with Kyverno in Audit mode
- Review violations in Policy Reporter UI
- Gradually enable Enforce mode
- See [Compliance Guide](compliance.md) for details

### Optimize Configuration

- Review [Observability Best Practices](observability.md)
- Check [Traffic Management Guide](traffic-management.md)
- Read [Elasticsearch Best Practices](elastic-best-practices.md)

## Troubleshooting

### Application Stuck in Syncing

```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Check Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force refresh
argocd app get <app-name> --refresh
```

### Component Pods Not Starting

```bash
# Check pod status
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Check for resource constraints
kubectl top nodes
kubectl top pods -A
```

### Certificate Not Issuing

```bash
# Check certificate status
kubectl describe certificate <cert-name>

# Check challenges
kubectl get challenges -A
kubectl describe challenge <challenge-name>

# Verify DNS
dig _acme-challenge.your-domain.com TXT
```

### Sealed Secret Not Unsealing

```bash
# Check sealed secret status
kubectl get sealedsecrets -A
kubectl describe sealedsecret <name> -n <namespace>

# Verify controller is running
kubectl get pods -n sealed-secrets

# Check controller logs
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets
```

For more troubleshooting help, see the [Troubleshooting Guide](troubleshooting.md) (when available) or component-specific documentation.

## Common Issues

### Issue: Argo CD Can't Access Repository

**Solution**: Ensure repository credentials are configured in Argo CD:
```bash
argocd repo add <repo-url> --ssh-private-key-path ~/.ssh/id_rsa
```

### Issue: Components Deploy Out of Order

**Solution**: Use sync waves in values files:
```yaml
sealedSecrets:
  enable: true
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
certManager:
  enable: true
  annotations:
    argocd.argoproj.io/sync-wave: "0"
```

### Issue: DNS Records Not Created

**Solution**: 
- Verify external-dns pod is running
- Check DNS provider credentials
- Verify domain filters match your domains
- Check external-dns logs

## Additional Resources

- [Argo CD Best Practices](argocd-best-practices.md)
- [Observability Guide](observability.md)
- [Traffic Management Guide](traffic-management.md)
- [Compliance Guide](compliance.md)
- [Main README](../README.md)

## Support

If you encounter issues not covered in this guide:
1. Check component-specific READMEs in `charts/<component>/README.md`
2. Review detailed architecture docs in `docs/`
3. Check Argo CD application status and logs
4. Verify all prerequisites are met

