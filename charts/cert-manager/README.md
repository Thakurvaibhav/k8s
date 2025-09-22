# cert-manager Chart

## Overview
This chart wraps (vendors) the upstream `cert-manager` and `reflector` Helm charts to provide automated X.509 certificate issuance plus namespace-wide (and cluster-wide) secret replication. It enables platform components (e.g. `envoy-gateway`, ingress controllers, internal services) to uniformly consume TLS certificates without duplicative issuance steps per namespace.

## Upstream Dependencies
| Dependency | Source | Purpose |
|------------|--------|---------|
| cert-manager | https://charts.jetstack.io | ACME / X.509 certificate issuance, CRDs (Issuers, ClusterIssuers, Certificates) |
| reflector | https://emberstack.github.io/helm-charts | Watches Secrets & ConfigMaps and reflects them across namespaces via annotations |

`installCRDs` is enabled so the required cert-manager CRDs are installed automatically on first deploy.

## DNS Providers
The provided templates demonstrate Google Cloud DNS (`dns01` solver with `cloudDNS` stanza) for ACME validation. However, cert-manager supports many DNS providers (Route53, Cloudflare, Azure DNS, Akamai, etc.). To switch providers, create or modify a solver entry under the `solvers:` list of the relevant (Cluster)Issuer manifest.

### GCP Cloud DNS Credentials
A sealed secret (value: `sealedgcpdnscredentials`) should contain a service account JSON with permissions to manage the target Cloud DNS zone(s). The solver section references:
```
serviceAccountSecretRef:
  name: gcp-dns-credentials
  key: gcp-dns-credentials.json
```
Ensure the unsealed secret is rendered via Sealed Secrets or another mechanism before cert-manager attempts a challenge.

## Secret Reflection (replicating certificate secrets)
The `reflector` controller enables automatic propagation of selected Secrets or ConfigMaps across namespaces. Certificates created by cert-manager include a `secretName` that holds the keypair. By annotating the Certificate's `secretTemplate` with:
```
reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
```
any produced Secret will be copied into other namespaces that opt-in (or automatically, depending on reflector configuration). This allows a single wildcard or multi-SAN certificate (e.g., `ingress-tls`) to be reused by:
- `envoy-gateway` for TLS termination on Gateway listeners
- Other ingress or gRPC endpoints needing the same domain coverage
- Internal services requiring the public cert bundle

Avoid reflecting highly sensitive key material unnecessarily; scope usage to public ingress certs.

## Typical Workflow
1. Deploy chart (installs cert-manager + reflector CRDs/controllers).
2. Ensure DNS credentials secret (sealed) is present in `cert-manager` namespace.
3. Apply or reconcile ClusterIssuer/Issuer templates (e.g., staging / prod ACME endpoints).
4. Certificates request ACME challenges; cert-manager completes `dns01` validation via Cloud DNS.
5. Issued certificate Secret is annotated and automatically replicated by reflector for consumers.

## Example Staging ClusterIssuer & Certificate
Excerpt (see `templates/certificates/stg-calicocloud-com.yaml`):
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-stgdomain
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: hostmaster@mydomain.com
    privateKeySecretRef:
      name: letsencrypt-stgdomain
    solvers:
      - dns01:
          cloudDNS:
            project: my-gcp-dns-project
            serviceAccountSecretRef:
              name: gcp-dns-credentials
              key: gcp-dns-credentials.json
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: stg-mydomain-com
  namespace: cert-manager
spec:
  dnsNames:
    - '*.staging.mydomain.com'
    - 'staging.mydomain.com'
  secretName: ingress-tls
  issuerRef:
    name: letsencrypt-stgdomain
    kind: ClusterIssuer
  secretTemplate:
    annotations:
      reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
      reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
```

## Switching to Another DNS Provider
Replace the solver block. Example (Cloudflare):
```yaml
solvers:
  - dns01:
      cloudflare:
        apiTokenSecretRef:
          name: cloudflare-api-token
          key: api-token
```
Remove the `cloudDNS` stanza and supply the provider-specific fields. Repeat for production & staging issuers.

## Values Overview (`values.yaml`)
- `cert-manager.installCRDs`: Ensure CRDs are installed (true for initial bootstrap).
- `cert-manager.resources.*`: Resource requests/limits for core cert-manager components.
- `reflector.resources.*`: Tuning for reflector controller.
- `sealedgcpdnscredentials`: Placeholder for sealed JSON key (rendered into secret by separate template if implemented).

## Security Considerations
- Scope DNS service account permissions to required zones only.
- Limit which secrets get reflection annotations; not all should be global.
- Rotate ACME account key (ClusterIssuer private key) if compromised.
- Use staging ACME endpoint for testing (Let’s Encrypt) before production certificates.

## Future Enhancements
- Add production vs staging ACME endpoint toggles via values.
- Integrate with external secret managers (e.g., External Secrets Operator).
- Optionally create DNS zone records automatically during bootstrap (infra IaC alignment).

## License
Internal use only unless stated otherwise.
