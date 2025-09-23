# kyverno Helm Chart

## Overview
This chart installs the upstream Kyverno admission controller and the Policy Reporter UI/metrics stack, and layers on a curated set of **starter policies** grouped into two categories:
- Ops policies (operational best practices: namespace usage, image tags, resource requests, NodePort usage)
- Security policies (RBAC binding hardening, registry restrictions, secret hygiene, ingress safety)

Policies are designed to be introduced safely in **Audit** mode first and then flipped to **enforce** (e.g., `Enforce`) once workloads are compliant. This enables progressive hardening without breaking existing deployments.

## Included Upstream Dependencies
Declared in `Chart.yaml`:
```
dependencies:
  - name: kyverno
    version: 3.3.9
    repository: https://kyverno.github.io/kyverno/
  - name: policy-reporter
    alias: policyReporter
    version: 3.1.3
    condition: policyReporter.enabled
    repository: https://kyverno.github.io/policy-reporter
```
- `kyverno`: Core policy engine (CRDs + controllers)
- `policy-reporter`: Optional UI, metrics, and reporting integrations (enabled via `policyReporter.enabled`)

## Policy Groups
| Group | File Path Prefix | Example Policies | Purpose |
|-------|------------------|------------------|---------|
| Ops | `templates/policies/ops/` | `disallow-default-ns`, `disallow-latest-tag`, `specify-resources`, `disallow-nodeport-service` | Enforce ops hygiene & resource governance |
| Security | `templates/policies/security/` | `restrict-image-registries`, `restrict-bind-to-cluster-admin`, `deny-secret-service-account-token`, `check-long-lived-secrets` | Strengthen security posture & RBAC, reduce attack surface |

Each policy file is self‑contained (definition + any future exceptions/report tuning). Toggle a policy by setting its `enabled: true/false` in values.

## Modes: Audit → Enforce
Every policy exposes a `mode` value (in your values files) that maps to Kyverno `failureAction`:
- `Audit` (non-blocking, generates policy reports; use for initial rollout)
- `Enforce` (blocking admission once confident)

Recommended rollout:
1. Enable selected policies with `mode: Audit` in lower environments.
2. Measure findings using Policy Reporter UI / metrics.
3. Remediate workloads (fix manifests, add explicit exceptions only where justified).
4. Flip `mode` to `Enforce` environment by environment.

## Values Structure (Excerpt)
```
opsPolicies:
  disallowDefaultNs:
    enabled: true
    mode: Audit
  disallowLatestTag:
    enabled: true
    mode: Audit
  specifyResources:
    enabled: true
    mode: Audit
  disallowNodePortService:
    enabled: true
    mode: Audit

secPolicies:
  restrictImageRegistries:
    enabled: true
    mode: Audit
  restrictIngressDefaultBackend:
    enabled: true
    mode: Audit
  restrictBindToSystemGroups:
    enabled: true
    mode: Audit
  restrictBindToClusterAdmin:
    enabled: true
    mode: Audit
  denySecretServiceAccountToken:
    enabled: true
    mode: Audit
  checkLongLivedSecrets:
    enabled: true
    mode: Audit
```
Override per environment in `values.<env>.yaml` to progress policy maturity.

## Installation
(Usually managed by the App‑of‑Apps root; direct install shown for reference.)
```bash
helm dependency update ./kyverno
helm upgrade --install kyverno ./kyverno -f kyverno/values.dev-01.yaml -n kyverno --create-namespace
```

## Policy Reporter
If `policyReporter.enabled=true` the chart deploys Policy Reporter (+ UI & Kyverno plugin) in the Kyverno namespace with Prometheus scrape annotations for metrics and dashboards.

## Adding New Policies
1. Choose group directory (`ops/` or `security/`); create a new YAML file.
2. Wrap the policy with a values conditional: `{{- if .Values.opsPolicies.newPolicy.enabled }}`.
3. Add `mode` key in `values.yaml` for `Audit`/`Enforce` control.
4. Document rationale via annotations (`policies.kyverno.io/description`).
5. Add exceptions (PolicyExceptions) as needed in same file or separate file referencing labels.

## Exceptions & Progressive Hardening
Kyverno supports PolicyExceptions (controller feature enabled). Prefer:
- Short‑lived, targeted exceptions
- Label‑based scoping
- Periodic review/expiration

## Metrics & Observability
- Kyverno exposes metrics on port 8000 (annotated for Prometheus scraping).
- Policy Reporter adds detailed counts, severities, and UI.
- Track reduction in Audit violations before switching to Enforce.

## Security Considerations
- Start restrictive policies (image registries, RBAC binds) in Audit to avoid blocking cluster bootstrap components.
- Use `restrict-image-registries` to lock down allowed registries; customize patterns before enforcing.
- Resource requirement enforcement (`specify-resources`) helps with multi‑tenant fairness & scheduling stability.

## Troubleshooting
| Issue | Cause | Action |
|-------|-------|--------|
| Policy not applied | `enabled: false` or file conditional mismatch | Set `enabled: true` and resync |
| Workload blocked unexpectedly | Mode switched to `Enforce` prematurely | Revert to `Audit`, add exception, or fix manifest |
| High violation count | Existing workloads non‑compliant | Remediate manifests; stage Enforce after reduction |
| Missing reports | Policy Reporter disabled | Enable `policyReporter.enabled=true` |

## Resource Tracking (Argo CD)
To avoid label ownership conflicts with the Kyverno Helm chart, configure Argo CD to use a different instance label key than the default `app.kubernetes.io/instance`. Example global setting:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  application.instanceLabelKey: argocd.argoproj.io/instance
```


## Upgrade Notes
- Pin dependency versions in `Chart.yaml`; bump deliberately for upstream changes.
- Validate new Kyverno versions for policy schema changes before promoting to production.

## License
Internal use unless specified otherwise.
