# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability, please report it via one of the following methods:

1. **Preferred**: Open a [GitHub Security Advisory](https://github.com/Thakurvaibhav/k8s/security/advisories/new)
2. **Alternative**: Email security concerns to the repository maintainer (if contact information is available)

### What to Include

When reporting a vulnerability, please include:

- **Description**: Clear description of the vulnerability
- **Affected Component**: Which chart/component is affected (e.g., cert-manager, envoy-gateway, sealed-secrets)
- **Severity**: Your assessment of the severity (Critical, High, Medium, Low)
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Potential Impact**: What could an attacker do with this vulnerability?
- **Suggested Fix**: If you have ideas on how to fix it (optional)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution**: Depends on severity and complexity
  - **Critical**: As soon as possible (target: 24-48 hours)
  - **High**: Within 7 days
  - **Medium/Low**: Within 30 days

### What to Expect

- **Acknowledgment**: You will receive acknowledgment of your report
- **Updates**: Regular updates on the status of the vulnerability
- **Credit**: If you wish, you will be credited for the discovery (after resolution)
- **Disclosure**: Vulnerabilities will be disclosed after a fix is available, following responsible disclosure practices

## Security Practices

This repository follows several security best practices:

### Secret Management

- **Sealed Secrets**: All secrets are encrypted using Bitnami Sealed Secrets before being committed to Git
- **No Plaintext Secrets**: Never commit unsealed secrets or credentials
- **Key Management**: Sealed Secrets controller keys must be backed up securely
- **Key Rotation**: Regular rotation of Sealed Secrets controller keys

### Container Image Security

- **Vulnerability Scanning**: All container images are scanned with Trivy in CI/CD
- **Image Policies**: Kyverno policies restrict which image registries can be used
- **Tag Restrictions**: Policies prevent use of `latest` tags in production
- **Regular Updates**: Keep base images and dependencies up to date

### Policy Enforcement

- **Kyverno Policies**: Runtime policy enforcement for security and compliance
- **Progressive Rollout**: Policies start in Audit mode before enforcement
- **CI Scanning**: Checkov scans Helm charts for security misconfigurations
- **RBAC**: Least privilege principle for all service accounts

### Network Security

- **TLS/mTLS**: All external-facing services use TLS; mTLS for service-to-service communication
- **Certificate Management**: Automated certificate issuance via cert-manager
- **Network Policies**: Consider implementing NetworkPolicies for namespace isolation (future enhancement)

### Multi-Cluster Security

- **Cluster Isolation**: Workload clusters isolated from each other
- **Centralized Control**: Ops cluster manages all clusters via Argo CD
- **Remote Cluster Registration**: Secure registration of remote clusters in Argo CD
- **mTLS for Observability**: Secure transport for metrics, logs, and traces

## Security Scanning

This repository includes automated security scanning:

### CI/CD Pipeline

- **Helm Lint**: Validates chart syntax and structure
- **Trivy**: Scans container images for vulnerabilities
- **Checkov**: Scans Helm charts for security misconfigurations

### Running Scans Locally

```bash
# Lint charts
scripts/scan.sh lint

# Scan images for vulnerabilities
scripts/scan.sh trivy

# Scan charts for misconfigurations
scripts/scan.sh checkov
```

### Scan Configuration

- Skipped charts/images: Configured in `scripts/scan-config.yaml`
- Per-chart ignores: `.trivyignore` and `.checkov.yaml` in chart directories
- Severity levels: Configurable via `TRIVY_SEVERITY` environment variable

## Security Considerations by Component

### Sealed Secrets
- **Key Backup**: Controller keys must be backed up securely
- **Key Rotation**: Documented process for rotating keys
- **Access Control**: RBAC restricts who can create SealedSecret resources

### Cert-Manager
- **ACME Credentials**: DNS service account credentials stored in Sealed Secrets
- **Certificate Lifecycle**: Automated renewal and rotation
- **Wildcard Certificates**: Used for efficiency, but consider scope

### Envoy Gateway
- **TLS Termination**: All ingress traffic encrypted
- **mTLS**: Configured for east-west traffic
- **Policy Enforcement**: Rate limiting, circuit breaking via ExtensionPolicy

### Kyverno
- **Policy Audit**: All policies start in Audit mode
- **Exception Handling**: Documented process for policy exceptions
- **Policy Reports**: Visible in Policy Reporter UI

### Monitoring & Logging
- **mTLS**: Secure transport for observability data
- **Access Control**: Grafana, Kibana, Jaeger Query protected with authentication
- **Data Retention**: Configured per environment requirements

## Security Best Practices for Contributors

1. **Never commit secrets**: Always use `kubeseal` to encrypt secrets before committing
2. **Review PRs carefully**: Check for hardcoded credentials, exposed secrets, or security misconfigurations
3. **Keep dependencies updated**: Regularly update Helm chart dependencies and base images
4. **Follow least privilege**: Service accounts should have minimal required permissions
5. **Use security scanning**: Run `scripts/scan.sh` before submitting PRs
6. **Document security changes**: Update relevant documentation when making security-related changes
7. **Test in dev first**: Always test security changes in dev environment before promoting

## Security Resources

- [Compliance & Policy Documentation](docs/compliance.md)
- [Argo CD Best Practices](docs/argocd-best-practices.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
- [Architecture Decision Records](docs/adr/) - See ADR-004 for Sealed Secrets rationale

## Acknowledgments

We appreciate responsible disclosure of security vulnerabilities. Thank you for helping keep this project secure.
