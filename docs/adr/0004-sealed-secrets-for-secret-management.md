# ADR-004: Use Sealed Secrets for GitOps Secret Management

## Status
Accepted

## Context

I needed a way to manage secrets in a GitOps workflow where:

- **Git is source of truth**: All configuration (including secrets) must be version-controlled
- **Security**: Secrets cannot be stored in plaintext in Git repositories
- **Declarative**: Secrets should be defined as Kubernetes resources (not external systems)
- **Multi-cluster**: Same secrets need to be deployed across multiple clusters
- **Automation-friendly**: CI/CD pipelines need to create/update secrets without manual steps
- **Audit trail**: Changes to secrets must be traceable in Git history
- **Collaboration**: Multiple engineers can update secrets safely

Traditional approaches have limitations:
- **Plaintext in Git**: Security risk, violates compliance requirements
- **External secret managers (Vault, AWS Secrets Manager)**: Requires additional infrastructure, not Git-native
- **Manual kubectl apply**: Not GitOps-compatible, no version control, error-prone
- **SOPS/age**: Requires key management, less Kubernetes-native
- **External Secrets Operator**: Depends on external systems, adds complexity

## Decision

I adopted **Bitnami Sealed Secrets** for encrypting secrets that can be safely committed to Git.

**How it works:**
1. Sealed Secrets controller runs in each cluster with a public/private key pair
2. Developers use `kubeseal` CLI to encrypt secrets, producing `SealedSecret` CRs
3. `SealedSecret` resources are committed to Git (encrypted, safe to store)
4. Sealed Secrets controller watches for `SealedSecret` resources
5. Controller decrypts and creates regular Kubernetes `Secret` resources
6. Applications consume the decrypted `Secret` as normal

**Key Features:**
- **Cluster-scoped encryption**: Each cluster has its own key (sealed secret for cluster A cannot be decrypted in cluster B)
- **Namespace-scoped**: Can restrict which namespaces can decrypt secrets
- **GitOps-native**: Encrypted secrets are YAML files in Git
- **No external dependencies**: Works entirely within Kubernetes
- **Audit trail**: All secret changes tracked in Git history
- **CI/CD friendly**: `kubeseal` can be run in pipelines

**Usage Pattern:**
```bash
# Encrypt a secret
kubectl create secret generic my-secret --dry-run=client -o yaml \
  | kubeseal -o yaml > sealed-my-secret.yaml

# Commit sealed-my-secret.yaml to Git
# Controller automatically creates my-secret in cluster
```

## Consequences

### Positive

- **GitOps-compatible**: Secrets are version-controlled and Git-managed
- **Security**: Secrets encrypted at rest in Git (cannot be decrypted without cluster key)
- **Audit trail**: All secret changes visible in Git history
- **No external dependencies**: Works entirely within Kubernetes
- **Declarative**: Secrets defined as Kubernetes resources
- **Multi-cluster support**: Different keys per cluster provide isolation
- **Collaboration**: Multiple engineers can update secrets (encrypted form)
- **CI/CD integration**: Automated secret creation in pipelines
- **Simple model**: Easy to understand and operate

### Negative

- **Key management**: Must securely backup and rotate Sealed Secrets controller keys
- **Key recovery**: Lost keys mean secrets cannot be decrypted (must re-seal)
- **Manual sealing step**: Developers must use `kubeseal` CLI (not fully automated)
- **No secret rotation**: Changing a secret requires re-sealing and redeploying
- **Limited features**: No secret versioning, expiration, or automatic rotation
- **Key exposure risk**: If controller key is compromised, all secrets in that cluster are compromised

### Mitigations

- **Key backup**: Documented process for backing up controller keys securely
- **Key rotation**: Runbook for rotating keys (re-seal all secrets with new key)
- **Access control**: RBAC restricts who can create SealedSecret resources
- **Monitoring**: Alert on SealedSecret creation failures
- **Documentation**: Clear process for sealing secrets in `docs/` and `AGENTS.md`

## Alternatives Considered

### 1. External Secrets Operator (ESO)
**Rejected because:**
- ESO is an excellent solution when you have existing secret stores (Vault, AWS Secrets Manager, etc.)
- For this use case, Git-native secret management was a key requirement
- ESO adds infrastructure dependency (must operate Vault or cloud secret manager)
- The architecture requires both the operator and external secret store, increasing complexity
- Sealed Secrets provides a simpler, Git-native approach that fits the GitOps workflow better

### 2. HashiCorp Vault
**Rejected because:**
- Vault is an industry-leading secret management solution with excellent features
- Vault excels at dynamic secrets, PKI, and complex secret management scenarios
- For this use case, Git-native secret management was required, and Vault stores secrets externally
- Vault's advanced features (dynamic secrets, PKI) weren't needed for this platform
- The operational overhead (HA setup, unsealing, policies) was more than required

### 3. SOPS with age/PGP
**Rejected because:**
- SOPS is a solid file-level encryption solution widely used in the industry
- For this use case, Kubernetes-native secret resources were preferred
- SOPS requires manual decryption steps in CI/CD, whereas Sealed Secrets integrates automatically
- Key management overhead (age keys or PGP keys) was a consideration
- Sealed Secrets provides better integration with Kubernetes workflows

### 4. Cloud Secret Managers (AWS Secrets Manager, GCP Secret Manager)
**Rejected because:**
- Cloud secret managers are excellent managed solutions that reduce operational overhead
- For this use case, Git-native secret management and multi-cloud portability were important
- Cloud-specific solutions create vendor lock-in and require cloud API integrations
- Cost at scale was a consideration for this self-hosted platform
- GitOps-native approach preferred declarative, version-controlled secrets

### 5. Plaintext in Git (with private repos)
**Rejected because:**
- Security risk (even in private repos)
- Compliance violations (many standards require encryption)
- Git history contains secrets forever (even if deleted)
- Accidental exposure risk (public repo mistakes, leaks)

### 6. Kubernetes Secrets with External Encryption (e.g., KMS)
**Rejected because:**
- Requires cloud KMS (vendor lock-in)
- Not Git-native (secrets not in Git)
- More complex key management
- Additional cost

## Implementation Notes

- Sealed Secrets controller deployed via Helm chart
- Controller key stored as Kubernetes Secret (must be backed up)
- Global secrets (shared across clusters) sealed per-cluster with cluster-specific keys
- CI/CD pipelines use `kubeseal` to create SealedSecret resources
- Documentation includes sealing procedures and key backup/rotation runbooks
- RBAC restricts SealedSecret creation to authorized users

## Key Management Best Practices

- **Backup keys**: Controller private key must be backed up securely
- **Key rotation**: Periodic rotation (re-seal all secrets with new key)
- **Key storage**: Store backup keys in secure location (encrypted, access-controlled)
- **Disaster recovery**: Document process for restoring controller with backed-up key

## References

- [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- Repository: `charts/sealed-secrets/`
- Usage: See `docs/getting-started.md` for sealing procedures

