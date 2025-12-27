# Troubleshooting Guide

This guide helps diagnose and resolve common issues when deploying and operating the Platform in a Box. Issues are organized by component and symptom.

## General Debugging Steps

Before diving into component-specific troubleshooting, follow these general steps:

### 1. Verify Cluster Connectivity
```bash
# Check cluster access
kubectl cluster-info
kubectl get nodes

# Verify you're connected to the correct cluster
kubectl config current-context
```

### 2. Check Namespace and Resources
```bash
# List all namespaces
kubectl get namespaces

# Check resources in a namespace
kubectl get all -n <namespace>

# Describe a resource for detailed status
kubectl describe <resource-type> <resource-name> -n <namespace>
```

### 3. Inspect Pod Logs
```bash
# Get pod logs
kubectl logs <pod-name> -n <namespace>

# Follow logs in real-time
kubectl logs -f <pod-name> -n <namespace>

# Get logs from previous container instance (if restarted)
kubectl logs <pod-name> -n <namespace> --previous

# Get logs from all pods with a label
kubectl logs -l app=<label-value> -n <namespace>
```

### 4. Check Events
```bash
# Get events for a namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n <namespace> --watch
```

### 5. Verify Argo CD Application Status
```bash
# List all applications
kubectl get applications -n argocd

# Get detailed application status
kubectl describe application <app-name> -n argocd

# Check sync status
argocd app get <app-name>

# View application diff
argocd app diff <app-name>
```

---

## Argo CD Issues

### Application Stuck in Syncing State

**Symptoms**: Application shows `Syncing` status for extended period

**Diagnosis**:
```bash
# Check application status
kubectl get application <app-name> -n argocd -o yaml

# Check Argo CD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Check repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Repository authentication failure | Verify repo credentials: `argocd repo get <repo-url>` |
| Helm dependency not updated | Run `helm dependency update` in chart directory |
| Resource conflicts (namespace/CRDs) | Check for existing resources: `kubectl get <resource> -A` |
| Sync wave ordering issue | Verify sync wave annotations are correct |
| Large manifest size | Check repo server memory limits |
| Git repository unreachable | Verify network connectivity and repository URL |

**Actions**:
```bash
# Force refresh application
argocd app get <app-name> --refresh

# Hard refresh (clears cache)
argocd app get <app-name> --hard-refresh

# Retry sync
argocd app sync <app-name>

# Check repository connection
argocd repo get <repo-url>
```

### Application Shows Unknown or Degraded Status

**Symptoms**: Application status is `Unknown` or `Degraded`

**Diagnosis**:
```bash
# Get application conditions
kubectl get application <app-name> -n argocd -o jsonpath='{.status.conditions}'

# Check health status
kubectl get application <app-name> -n argocd -o jsonpath='{.status.health}'

# View full application spec
kubectl get application <app-name> -n argocd -o yaml
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Destination cluster unreachable | Verify cluster connectivity: `kubectl get --raw /healthz` |
| Namespace doesn't exist | Enable `CreateNamespace=true` in sync options |
| Resource validation failed | Check resource YAML for syntax errors |
| CRDs not installed | Install required CRDs before application sync |
| RBAC permissions insufficient | Verify service account has required permissions |

**Actions**:
```bash
# Check destination cluster
kubectl get --raw /healthz --context=<cluster-context>

# Create namespace manually if needed
kubectl create namespace <namespace>

# Check RBAC
kubectl auth can-i create deployments --namespace=<namespace>
```

### Repository Authentication Issues

**Symptoms**: Argo CD cannot fetch from Git repository

**Diagnosis**:
```bash
# List repositories
argocd repo list

# Get repository details
argocd repo get <repo-url>

# Test repository connection
argocd repo get <repo-url> --refresh
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| SSH key not configured | Add SSH key: `argocd repo add <repo-url> --ssh-private-key-path ~/.ssh/id_rsa` |
| HTTPS credentials missing | Add credentials: `argocd repo add <repo-url> --username <user> --password <pass>` |
| Repository URL incorrect | Verify repository URL format |
| Network/firewall blocking | Check network connectivity to Git provider |

**Actions**:
```bash
# Add SSH repository
argocd repo add git@github.com:org/repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Add HTTPS repository
argocd repo add https://github.com/org/repo.git \
  --username <user> \
  --password <token>

# Remove and re-add repository
argocd repo rm <repo-url>
argocd repo add <repo-url> [credentials]
```

---

## Sealed Secrets Issues

### Secret Not Created After Unsealing

**Symptoms**: SealedSecret exists but Secret is not created

**Diagnosis**:
```bash
# Check sealed secret status
kubectl get sealedsecrets -A
kubectl describe sealedsecret <name> -n <namespace>

# Check if secret exists
kubectl get secret <name> -n <namespace>

# Check controller logs
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets --tail=50
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Wrong scope (namespace vs cluster-wide) | Reseal with correct scope: `kubeseal --scope=namespace-wide --namespace=<ns>` |
| Controller not running | Check pod status: `kubectl get pods -n sealed-secrets` |
| Wrong controller key | Verify using correct sealing key for this cluster |
| Namespace mismatch | Ensure SealedSecret is in correct namespace |

**Actions**:
```bash
# Verify controller is running
kubectl get pods -n sealed-secrets

# Check controller logs for errors
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets

# Reseal with correct scope
kubeseal --cert=pub-cert.pem \
  --scope=namespace-wide \
  --namespace=<target-namespace> \
  --format=yaml < secret.yaml > sealed-secret.yaml
```

### Decryption Failed

**Symptoms**: Controller logs show decryption errors

**Diagnosis**:
```bash
# Check controller logs
kubectl logs -n sealed-secrets -l app.kubernetes.io/name=sealed-secrets | grep -i decrypt

# Verify active key
kubectl get secrets -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active

# Check sealed secret encryption
kubectl get sealedsecret <name> -n <namespace> -o yaml
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Wrong controller key (rotated/missing) | Restore original key or reseal with new cert |
| Multiple active keys | Ensure only one key has `sealed-secrets-key=active` label |
| Key corruption | Restore key from backup |

**Actions**:
```bash
# List all keys
kubectl get secrets -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key

# Verify active key
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active

# If key rotated, reseal secrets with new cert
kubeseal --fetch-cert > new-pub-cert.pem
kubeseal --cert=new-pub-cert.pem < secret.yaml > sealed-secret.yaml
```

---

## Certificate Manager Issues

### Certificate Not Issuing

**Symptoms**: Certificate stuck in `Pending` or shows `Failed` status

**Diagnosis**:
```bash
# Check certificate status
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Check certificate orders
kubectl get orders -A
kubectl describe order <order-name> -n <namespace>

# Check challenges
kubectl get challenges -A
kubectl describe challenge <challenge-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager --tail=100
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| DNS provider credentials incorrect | Verify secret exists and contains correct credentials |
| DNS propagation delay | Wait for DNS TTL period, check with `dig` |
| ACME rate limits | Use Let's Encrypt staging endpoint for testing |
| ClusterIssuer not configured | Verify ClusterIssuer exists and is ready |
| DNS zone permissions insufficient | Check IAM/service account permissions |
| Network connectivity to ACME | Verify egress to Let's Encrypt API |

**Actions**:
```bash
# Verify DNS credentials secret
kubectl get secret <dns-credentials-secret> -n cert-manager
kubectl describe secret <dns-credentials-secret> -n cert-manager

# Check DNS challenge record
dig _acme-challenge.<domain> TXT

# Verify ClusterIssuer
kubectl get clusterissuers
kubectl describe clusterissuer <issuer-name>

# Force certificate renewal
kubectl annotate certificate <cert-name> -n <namespace> \
  cert-manager.io/issue-temporary-certificate=true

# Check cert-manager controller logs
kubectl logs -n cert-manager -l app.kubernetes.io/name=cert-manager | grep -i error
```

### Certificate Expiring Soon

**Symptoms**: Alert or warning about certificate expiration

**Diagnosis**:
```bash
# Check certificate expiration
kubectl get certificates -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.notAfter}{"\n"}{end}'

# Describe certificate
kubectl describe certificate <cert-name> -n <namespace>
```

**Actions**:
```bash
# Force renewal
kubectl delete secret <cert-secret-name> -n <namespace>
# Cert-manager will automatically renew

# Or annotate to trigger renewal
kubectl annotate certificate <cert-name> -n <namespace> \
  cert-manager.io/issue-temporary-certificate=true
```

---

## Envoy Gateway Issues

### Gateway Not Ready

**Symptoms**: Gateway status shows `NotReady` or listeners not accepting traffic

**Diagnosis**:
```bash
# Check gateway status
kubectl get gateways -A
kubectl describe gateway <gateway-name> -n <namespace>

# Check gateway controller logs
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/name=envoy-gateway --tail=100

# Check envoy proxy pods
kubectl get pods -n envoy-gateway-system
kubectl logs -n envoy-gateway-system -l app.kubernetes.io/name=envoy-gateway
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Load balancer not provisioned | Check cloud provider LB status |
| TLS certificate not ready | Verify certificate exists and is valid |
| Port conflicts | Check for port conflicts with other services |
| Resource constraints | Verify node resources and pod limits |
| Network policies blocking | Check NetworkPolicy rules |

**Actions**:
```bash
# Check gateway listeners
kubectl get gateway <gateway-name> -n <namespace> -o yaml | grep -A 10 listeners

# Verify service and endpoints
kubectl get svc -n envoy-gateway-system
kubectl get endpoints -n envoy-gateway-system

# Check load balancer status
kubectl get svc -n envoy-gateway-system -o jsonpath='{.items[*].status.loadBalancer}'
```

### HTTPRoute Not Routing Traffic

**Symptoms**: HTTPRoute exists but traffic not reaching backend

**Diagnosis**:
```bash
# Check HTTPRoute status
kubectl get httproute -A
kubectl describe httproute <route-name> -n <namespace>

# Check gateway status
kubectl get gateway <gateway-name> -n <namespace>

# Check backend service
kubectl get svc <backend-service> -n <namespace>
kubectl get endpoints <backend-service> -n <namespace>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| HTTPRoute not attached to Gateway | Verify `parentRefs` in HTTPRoute |
| Backend service has no endpoints | Check service selector matches pod labels |
| Port mismatch | Verify port in `backendRefs` matches service port |
| Hostname mismatch | Ensure hostname in HTTPRoute matches Gateway listener |
| Backend service not ready | Check backend pods are running and ready |

**Actions**:
```bash
# Verify HTTPRoute parent reference
kubectl get httproute <route-name> -n <namespace> -o yaml | grep -A 5 parentRefs

# Check backend service endpoints
kubectl get endpoints <backend-service> -n <namespace>

# Test backend directly
kubectl port-forward svc/<backend-service> -n <namespace> <port>:<port>

# Check envoy proxy configuration
kubectl exec -n envoy-gateway-system <envoy-pod> -- envoy admin config_dump
```

---

## External DNS Issues

### DNS Records Not Created

**Symptoms**: Services/HTTPRoutes annotated but DNS records not appearing

**Diagnosis**:
```bash
# Check external-dns logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=100

# Verify external-dns is running
kubectl get pods -n external-dns

# Check DNS provider connectivity
kubectl exec -n external-dns <pod-name> -- nslookup <domain>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| DNS provider credentials incorrect | Verify secret contains correct credentials |
| Domain filter mismatch | Check `domainFilters` in external-dns config |
| Insufficient IAM permissions | Verify service account has DNS write permissions |
| TXT registry conflict | Check for conflicting TXT records |
| Annotation missing or incorrect | Verify `external-dns.alpha.kubernetes.io/hostname` annotation |

**Actions**:
```bash
# Verify DNS credentials
kubectl get secret <dns-credentials> -n external-dns

# Check domain filters
kubectl get configmap -n external-dns external-dns -o yaml | grep domainFilters

# Verify annotations on service/route
kubectl get svc <service-name> -n <namespace> -o yaml | grep external-dns
kubectl get httproute <route-name> -n <namespace> -o yaml | grep external-dns

# Check DNS provider directly
# For Google Cloud DNS:
gcloud dns record-sets list --zone=<zone-name>

# For Route53:
aws route53 list-resource-record-sets --hosted-zone-id=<zone-id>
```

### DNS Records Not Updating

**Symptoms**: DNS records exist but point to old IPs

**Diagnosis**:
```bash
# Check external-dns sync status
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep -i sync

# Verify current desired state
kubectl get svc -A -o jsonpath='{range .items[*]}{.metadata.annotations.external-dns\.alpha\.kubernetes\.io/hostname}{"\n"}{end}'
```

**Actions**:
```bash
# Force external-dns to reconcile
kubectl delete pod -n external-dns -l app.kubernetes.io/name=external-dns

# Check DNS TTL (may need to wait)
dig <hostname> +short
```

---

## Monitoring (Prometheus/Thanos) Issues

### Prometheus Not Scraping Targets

**Symptoms**: No metrics appearing in Prometheus

**Diagnosis**:
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100

# Verify ServiceMonitor resources
kubectl get servicemonitors -A
kubectl describe servicemonitor <name> -n <namespace>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| ServiceMonitor not created | Create ServiceMonitor for service |
| Service annotations missing | Add `prometheus.io/scrape: "true"` annotation |
| Network policies blocking | Check NetworkPolicy allows Prometheus access |
| Service endpoints empty | Verify service has ready endpoints |
| Scrape config incorrect | Check Prometheus scrape configuration |

**Actions**:
```bash
# Check Prometheus configuration
kubectl get configmap -n monitoring prometheus -o yaml

# Verify ServiceMonitor selector
kubectl get servicemonitor <name> -n <namespace> -o yaml | grep -A 5 selector

# Check service has endpoints
kubectl get endpoints <service-name> -n <namespace>

# Test scrape manually
kubectl port-forward svc/<service-name> -n <namespace> 8080:8080
curl http://localhost:8080/metrics
```

### Thanos Sidecar Not Uploading Blocks

**Symptoms**: No blocks appearing in object storage bucket

**Diagnosis**:
```bash
# Check sidecar logs
kubectl logs -n monitoring -l app=prometheus -c thanos-sidecar --tail=100

# Check sidecar metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/metrics | grep thanos_sidecar

# Verify object storage credentials
kubectl get secret <thanos-credentials> -n monitoring
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Object storage credentials incorrect | Verify secret contains correct credentials |
| Bucket permissions insufficient | Check IAM/service account has write permissions |
| Network egress blocked | Verify cluster can reach object storage API |
| Sidecar configuration error | Check sidecar args and environment variables |
| Bucket doesn't exist | Create bucket before deployment |

**Actions**:
```bash
# Verify object storage secret
kubectl get secret <thanos-credentials> -n monitoring -o yaml

# Check sidecar configuration
kubectl get statefulset prometheus -n monitoring -o yaml | grep -A 20 thanos-sidecar

# Test object storage connectivity
kubectl exec -n monitoring <prometheus-pod> -c thanos-sidecar -- \
  thanos tools bucket verify --objstore.config-file=/etc/thanos/objstore.yaml

# Check bucket contents (GCS example)
gsutil ls gs://<bucket-name>/
```

### Thanos Query Not Showing All Clusters

**Symptoms**: Global Thanos Query missing metrics from some clusters

**Diagnosis**:
```bash
# Check Thanos Query configuration
kubectl get deployment thanos-query -n monitoring -o yaml

# Check Query logs
kubectl logs -n monitoring -l app.kubernetes.io/name=thanos-query --tail=100

# Verify Store API endpoints
kubectl get svc -A | grep thanos-query
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Local Query endpoints not configured | Verify `--store` flags point to local queries |
| mTLS certificate issues | Check client certs are valid and trusted |
| Network connectivity | Verify Query can reach local Query endpoints |
| External labels mismatch | Ensure `cluster` label is consistent |

**Actions**:
```bash
# Check Query store endpoints
kubectl get deployment thanos-query -n monitoring -o yaml | grep -A 5 --store

# Test connectivity to local queries
kubectl exec -n monitoring <thanos-query-pod> -- \
  wget -O- https://<local-query-endpoint>/api/v1/stores

# Verify external labels
kubectl get prometheus -n monitoring -o yaml | grep externalLabels
```

---

## Logging (Elasticsearch) Issues

### Elasticsearch Cluster Not Healthy

**Symptoms**: Cluster status shows `RED` or `YELLOW`

**Diagnosis**:
```bash
# Check Elasticsearch status
kubectl get elasticsearch -n logging
kubectl describe elasticsearch <name> -n logging

# Check cluster health via API
kubectl port-forward -n logging svc/elasticsearch-es-http 9200:9200
curl -u elastic:password https://localhost:9200/_cluster/health?pretty

# Check pod status
kubectl get pods -n logging -l elasticsearch.k8s.elastic.co/cluster-name
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Insufficient nodes | Scale up node count or adjust replicas |
| Disk space full | Check PVC usage: `kubectl get pvc -n logging` |
| Shard allocation issues | Check: `curl .../_cluster/allocation/explain` |
| Node failures | Check pod status and events |
| Resource constraints | Verify CPU/memory requests and limits |

**Actions**:
```bash
# Check cluster allocation explanation
curl -u elastic:password https://localhost:9200/_cluster/allocation/explain?pretty

# Check disk usage
kubectl get pvc -n logging
kubectl describe pvc <pvc-name> -n logging

# Check node status
curl -u elastic:password https://localhost:9200/_cat/nodes?v

# Check indices status
curl -u elastic:password https://localhost:9200/_cat/indices?v
```

### Filebeat Not Shipping Logs

**Symptoms**: No logs appearing in Elasticsearch indices

**Diagnosis**:
```bash
# Check Filebeat pods
kubectl get pods -n logging -l app=filebeat

# Check Filebeat logs
kubectl logs -n logging -l app=filebeat --tail=100

# Verify Filebeat configuration
kubectl get configmap filebeat -n logging -o yaml
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Elasticsearch endpoint unreachable | Verify ES service and network policies |
| mTLS certificate issues | Check client certs are valid |
| Filebeat configuration error | Verify output.elasticsearch settings |
| Network policies blocking | Check NetworkPolicy allows egress to ES |
| Index template missing | Create index template in Elasticsearch |

**Actions**:
```bash
# Check Filebeat output configuration
kubectl get configmap filebeat -n logging -o yaml | grep -A 10 output

# Test Elasticsearch connectivity
kubectl exec -n logging <filebeat-pod> -- \
  curl -k https://elasticsearch-es-http.logging:9200

# Verify mTLS certificates
kubectl get secret <filebeat-cert> -n logging
```

### Kibana Not Accessible

**Symptoms**: Cannot access Kibana UI

**Diagnosis**:
```bash
# Check Kibana pod status
kubectl get pods -n logging -l kibana.k8s.elastic.co/name

# Check Kibana logs
kubectl logs -n logging -l kibana.k8s.elastic.co/name --tail=100

# Verify HTTPRoute/Gateway
kubectl get httproute -n logging
kubectl get gateway -n logging
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| HTTPRoute not configured | Create HTTPRoute for Kibana service |
| Gateway not ready | Check Gateway status |
| TLS certificate issues | Verify certificate is valid |
| Elasticsearch connection failed | Check Kibana can reach Elasticsearch |

**Actions**:
```bash
# Check Kibana service
kubectl get svc -n logging | grep kibana

# Verify HTTPRoute
kubectl get httproute kibana -n logging -o yaml

# Test Kibana endpoint
kubectl port-forward -n logging svc/kibana-kb-http 5601:5601
# Visit http://localhost:5601
```

---

## Kyverno Policy Issues

### Policy Not Applied

**Symptoms**: Policy exists but not enforcing or auditing

**Diagnosis**:
```bash
# Check policy status
kubectl get clusterpolicies
kubectl get policies -A
kubectl describe clusterpolicy <name>

# Check Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=100
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Policy `enabled: false` in values | Set `enabled: true` in chart values |
| Policy file conditional mismatch | Verify Helm template condition matches values |
| Kyverno controller not running | Check pod status: `kubectl get pods -n kyverno` |
| Policy validation errors | Check policy YAML syntax |

**Actions**:
```bash
# Verify policy is enabled
kubectl get clusterpolicy <name> -o yaml | grep -A 5 spec

# Check Kyverno admission controller
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno

# Test policy manually
kubectl apply -f <test-resource.yaml>
```

### Workload Blocked Unexpectedly

**Symptoms**: Valid workloads rejected by Kyverno

**Diagnosis**:
```bash
# Check policy reports
kubectl get policyreports -A
kubectl describe policyreport <name> -n <namespace>

# Check admission request logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno | grep -i deny

# Verify policy mode
kubectl get clusterpolicy <name> -o jsonpath='{.spec.rules[*].validate.failureAction}'
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Policy switched to Enforce prematurely | Revert to Audit mode or add exception |
| Exception label missing | Add required exception label to resource |
| Policy rule too restrictive | Review and adjust policy rules |
| Namespace not excluded | Add namespace to policy exclusions |

**Actions**:
```bash
# Check policy failure action
kubectl get clusterpolicy <name> -o yaml | grep failureAction

# Add exception label
kubectl label <resource> policy.exception/<rule>=approved

# Temporarily disable policy
kubectl patch clusterpolicy <name> -p '{"spec":{"validationFailureAction":"Audit"}}'
```

---

## Network & Connectivity Issues

### Pods Cannot Reach Services

**Symptoms**: Pods cannot connect to other services in cluster

**Diagnosis**:
```bash
# Test connectivity from pod
kubectl exec -n <namespace> <pod-name> -- curl <service-name>.<namespace>.svc.cluster.local

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Verify DNS resolution
kubectl exec -n <namespace> <pod-name> -- nslookup <service-name>
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Network policies blocking | Check NetworkPolicy rules |
| Service selector mismatch | Verify service selector matches pod labels |
| DNS issues | Check CoreDNS pods and configuration |
| CNI plugin issues | Verify CNI pods are running |

**Actions**:
```bash
# Check NetworkPolicies
kubectl get networkpolicies -A
kubectl describe networkpolicy <name> -n <namespace>

# Verify service selector
kubectl get svc <service-name> -n <namespace> -o yaml | grep selector
kubectl get pods -n <namespace> -l <selector>

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

### External Connectivity Issues

**Symptoms**: Cannot reach external services from pods

**Diagnosis**:
```bash
# Test external connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -O- https://www.google.com

# Check egress network policies
kubectl get networkpolicies -A | grep -i egress

# Verify node network
kubectl get nodes -o wide
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| Egress network policies blocking | Review and adjust NetworkPolicy egress rules |
| Node network issues | Check node network configuration |
| Firewall rules | Verify cloud provider firewall rules |
| NAT gateway issues | Check NAT gateway configuration |

---

## Storage & Persistence Issues

### PVC Not Bound

**Symptoms**: PersistentVolumeClaim stuck in `Pending` state

**Diagnosis**:
```bash
# Check PVC status
kubectl get pvc -A
kubectl describe pvc <name> -n <namespace>

# Check available storage classes
kubectl get storageclass

# Check PVs
kubectl get pv
```

**Common Causes & Solutions**:

| Cause | Solution |
|-------|----------|
| No storage class specified | Set `storageClassName` in PVC |
| Storage class doesn't exist | Create StorageClass or use default |
| Insufficient storage | Check available storage in cluster |
| Provisioner not working | Check storage provisioner pods |

**Actions**:
```bash
# Check storage classes
kubectl get storageclass

# Verify default storage class
kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}'

# Check provisioner logs
kubectl logs -n <provisioner-namespace> -l app=<provisioner>
```

### Disk Space Full

**Symptoms**: Pods evicted or cannot write data

**Diagnosis**:
```bash
# Check node disk usage
kubectl top nodes

# Check PVC usage
kubectl get pvc -A
df -h  # on nodes

# Check pod eviction events
kubectl get events -A | grep -i evict
```

**Actions**:
```bash
# Expand PVC (if supported)
kubectl patch pvc <name> -n <namespace> -p '{"spec":{"resources":{"requests":{"storage":"<new-size>"}}}}'

# Clean up unused images
# On nodes: docker system prune -a

# Delete unused PVCs
kubectl get pvc -A | grep Released
kubectl delete pvc <name> -n <namespace>
```

---

## Performance Issues

### High Resource Usage

**Symptoms**: Pods throttled or OOMKilled

**Diagnosis**:
```bash
# Check resource usage
kubectl top pods -A
kubectl top nodes

# Check resource limits
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].resources}{"\n"}{end}'

# Check for OOMKilled
kubectl get pods -A | grep -i oom
```

**Actions**:
```bash
# Adjust resource requests/limits
kubectl set resources deployment <name> -n <namespace> \
  --requests=cpu=500m,memory=512Mi \
  --limits=cpu=1000m,memory=1Gi

# Scale horizontally
kubectl scale deployment <name> -n <namespace> --replicas=<count>
```

### Slow Application Sync

**Symptoms**: Argo CD applications take long time to sync

**Diagnosis**:
```bash
# Check sync duration
argocd app get <app-name> | grep Sync

# Check repo server performance
kubectl top pods -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Check application controller queue
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller | grep queue
```

**Actions**:
```bash
# Scale repo server
kubectl scale deployment argocd-repo-server -n argocd --replicas=<count>

# Increase repo server resources
kubectl set resources deployment argocd-repo-server -n argocd \
  --requests=memory=2Gi,cpu=1000m \
  --limits=memory=4Gi,cpu=2000m
```

---

## Getting Additional Help

If you cannot resolve an issue using this guide:

1. **Check Component-Specific Documentation**:
   - Chart READMEs in `charts/<component>/README.md`
   - Architecture docs in `docs/`

2. **Review Logs**:
   - Component pod logs
   - Argo CD application controller logs
   - Kubernetes events

3. **Verify Configuration**:
   - Values files match expected format
   - Secrets are correctly sealed
   - Resource versions are compatible

4. **Check Known Issues**:
   - GitHub issues (if public)
   - Component upstream documentation
   - Argo CD release notes

5. **Escalate / Reach Out**:
   - If you're stuck or need further help, feel free to reach out to me directly.
   - Component maintainers
   - Upstream project support channels

---

## Quick Reference: Common Commands

```bash
# Argo CD
argocd app list
argocd app get <app-name>
argocd app sync <app-name>
argocd app diff <app-name>

# Kubernetes
kubectl get all -n <namespace>
kubectl describe <resource> <name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Debugging
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
kubectl port-forward svc/<service> -n <namespace> <local-port>:<service-port>
kubectl run debug-pod --image=busybox --rm -it -- /bin/sh
```

