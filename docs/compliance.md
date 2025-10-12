# Policy & Compliance (Runtime Enforcement + Shift‑Left)

A consistent policy & compliance layer ensures platform guardrails are **predictable, observable, progressive, and reversible**. This document outlines how to use **Kyverno** (cluster runtime admission / mutation / validation) and **Checkov** (CI Infrastructure-as-Code scanning) under the same GitOps promotion model (App‑of‑Apps) to prevent last‑minute surprises.

---
## 1. Goals & Scope
- Enforce baseline security, reliability, and hygiene controls early (CI) and at runtime (admission).
- Provide safe adoption path: ALL policies start non‑blocking (audit) before graduated enforcement.
- Avoid lockouts (exclude system / bootstrap namespaces, phased enablement per cluster).
- Offer transparent visibility (Kyverno policy reports + report-ui UI + CI scan outputs).
- Permit tightly scoped, traceable exceptions (labels/annotations, dedicated exception Policies) – not ad‑hoc cluster edits.

In Scope: Kubernetes resource policies (Pods, Deployments, Ingress/Gateway, Secrets config), Helm chart templates (pre-commit / PR) (Checkov). Out of Scope: Runtime container behavior (handled by other controls) and cloud account CSPM (separate program).

---
## 2. Kyverno: Cluster Policy Engine
Kyverno operates inside each cluster as an admission controller applying:
- Validate rules (block or audit) – e.g. require labels, disallow privileged, enforce host suffix patterns.
- Mutate rules – inject defaults (resource limits, securityContext).
- Generate rules – create derivative resources (ConfigMaps, NetworkPolicies) based on source objects.
- VerifyImages (optional) – signature / attestation enforcement.

> Kyverno advantages: Native K8s resources (no custom DSL needed), policy CRDs stored in Git, integrates cleanly with App‑of‑Apps for multi‑cluster rollout.

---
## 3. Progressive Rollout Strategy (Audit → Enforce Ladder)
All new policies follow this state machine:
```
Draft (local branch) → Audit (dev) → Audit (staging) → Audit (prod) → Enforce (dev) → Enforce (staging) → Enforce (prod)
```
Rules:
- Minimum soak time in audit (collect report data) before first enforce step.
- No direct Draft → Enforce jumps.
- Regressions (excess violations) revert to Audit via Git commit (fast rollback).

Key spec fields:
```yaml
validate:
  failureAction: Audit   # later switched to Enforce
  failureActionOverrides:  # fine-grained exceptions (optional)
    - action: Audit
      namespaces: ["job-runner"]
```

---
## 4. Namespace & System Exclusions (Avoid Lockout)
Exclude critical namespaces from *initial* enforcement to prevent cluster bootstrap or core service disruption:
- `kube-system`, `kube-public`, `kube-node-lease`
- Argo CD control plane namespace
- Kyverno’s own namespace
- CNI / CSI driver namespaces
- Any sealed-secrets, cert-manager, gateway controller namespaces (early phases)

Implementation patterns:
- Policy `match` selector restricts to application namespaces via label (e.g. `team` / `app`) instead of excluding system namespaces repeatedly.
- `exclude` block for explicit carve-outs until workloads remediated:
```yaml
match:
  any:
    - resources:
        kinds: [Pod]
        namespaces: ["*"]
exclude:
  any:
    - resources:
        namespaces: ["kube-system", "kyverno", "argocd"]
```

---
## 5. Conditional / Scoped Exceptions
Prefer **structured exception channels**, not ad-hoc disabling:
1. Dedicated label (e.g. `policy.exception/<rule>=approved`) added via pull request with reviewer sign‑off.
2. Kyverno rule references label in a `precondition` or `pattern` negation.
3. Time-bounded exceptions (tracked in Git with TODO / expiry annotation).

Example (skip privileged check if approved):
```yaml
preconditions:
  all:
    - key: "{{ request.object.metadata.labels.policy.exception/allow-privileged }}"
      operator: NotEquals
      value: "true"
```
If teams need conditional resources (jobs, migrations), provide a separate *Generate* NetworkPolicy or allowlist policy limited by annotation.

---
## 6. Observability & Reporting
Install **Kyverno Policy Reports** + **report-ui** to surface:
- Violations grouped by policy → cluster → namespace.
- Trend lines (decreasing violation rate before enforcing).
- Drilldown: object YAML diff vs expected pattern.

Argo CD sync ensures report-ui is versioned like policies. Grafana (optional) can scrape `kyverno_policy_results_total` metrics for alerting (e.g. spike after new chart release).

Operational checks:
| Check | Command | Outcome |
|-------|---------|---------|
| Policy CR status | `kubectl get policyreports` | Shows counts (pass/warn/fail) |
| Specific rule | `kubectl get clusterpolicy disallow-privileged -o yaml` | Confirms `failureAction` |
| Report UI | Browser → `/kyverno/` path | Lists policies & violations |

---
## 7. Enforcement Maturity Roadmap
| Phase | Focus | Actions |
|-------|-------|---------|
| 0 | Visibility | Deploy Kyverno + policies (Audit) + report-ui |
| 1 | Hygiene | Enforce low-risk (labels, resource limits) |
| 2 | Security Baseline | Enforce no privileged / hostPath / forbidden capabilities |
| 3 | Image Integrity | Add VerifyImages (signatures), still audit first |
| 4 | Supply Chain | Enforce provenance attestations (later) |

Graduation criteria: sustained low (near-zero) audit violations for 1–2 release cycles in staging.

---
## 8. Shift‑Left With Checkov (CI Guardrails)
**Checkov** scans Terraform, Kubernetes manifests (Helm-rendered), and other IaC artifacts **before** merge:
- Prevents late-stage admission failures (e.g. disallowed capabilities) by failing PR early.
- Ensures cloud infra (buckets, networks, IAM) aligns with baseline (encryption, versioning, least privilege) complementary to runtime Kyverno (which only sees K8s API objects).

Pipeline pattern:
1. Render Helm templates (`helm template`) for changed charts.
2. Run Checkov on rendered manifests + Terraform modules (scoped to diff paths).
3. Output SARIF / JUnit for PR comment + artifact retention.
4. Block merge on critical failed checks.

Alignment with Kyverno:
- Same naming conventions (`cluster`, `environment` labels) enforced both in CI (Checkov custom policies) and at runtime (Kyverno validate rules).
- Reduces noise: by the time manifests reach cluster, most structural violations already fixed.

---
## 9. Workflow Example (Dev → Prod)
1. Developer adds new Deployment chart change lacking resource limits.
2. CI renders chart → Checkov fails (missing limits) → PR updated with limits.
3. Merged; Argo CD syncs dev cluster; Kyverno (Audit) still records 0 violations.
4. After audit stability, platform team flips corresponding Kyverno policy to `Enforce` in dev.
5. Promote revision to staging (still Enforce) after soak → finally to prod.
6. Future similar PRs blocked earlier (CI) + runtime policy prevents drift.

---
## 10. Operational Playbook
| Task | Action | Tool |
|------|--------|------|
| Add new policy | Author ClusterPolicy (Audit), commit to dev values / policies dir | GitOps + Argo |
| Review violations | Open report-ui, filter by namespace / policy | UI |
| Promote to staging | Merge branch updating `failureAction` (still Audit) | Git |
| Enforce policy | Change `failureAction: Enforce` after thresholds | Git |
| Add exception | PR adding label/annotation + (optional) policy precondition tweak | Git |
| Rollback enforcement | Revert commit (Enforce → Audit) | Git |
| Monitor spike | Alert on metric delta (violations/min) | Grafana |

---
## 11. Summary
- Kyverno supplies **runtime guardrails**; EVERY policy begins in **Audit** to gather signal safely.
- Namespace/resource exclusions + label-scoped matching prevent accidental platform disruption.
- Exceptions are **structured, labeled, reviewable**, not ad hoc edits.
- report-ui + metrics provide clear visibility to drive confident enforcement decisions.
- Checkov gives **shift‑left** assurance: infrastructure & manifest misconfigurations are surfaced pre‑merge, shrinking Kyverno violation noise.
- App‑of‑Apps enables **gradual, cluster-by-cluster enablement** and controlled promotion of enforcement states through the same branching/tag strategy used for traffic & observability.

Adopt iteratively: visibility first (Audit), then low-risk hygiene, then privilege/security, then supply chain controls.
