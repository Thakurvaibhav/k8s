# Letsencrypt certificate manager for Kuberntes on GKE 

### Prequisites

1. Access to GKE cluster
2. Access to GCP project with admin permissions for IAM and Cloud DNS
3. Replace fields below as per requirement


## Create gcloud service account for domain management

```
GCP_PROJECT=<GCP_PROJECT_NAME>

gcloud iam service-accounts create dns-admin --display-name=dns-admin --project=${GCP_PROJECT}

gcloud iam service-accounts keys create ./gcp-dns-admin.json --iam-account=dns-admin@${GCP_PROJECT}.iam.gserviceaccount.com --project=${GCP_PROJECT}

gcloud projects add-iam-policy-binding ${GCP_PROJECT} --member=serviceAccount:dns-admin@${GCP_PROJECT}.iam.gserviceaccount.com --role=roles/dns.admin

``` 

## Deploy cert-manager

```
kubectl create ns cert-manager

kubectl -n cert-manager create secret generic cert-manager-credentials --from-file=./gcp-dns-admin.json

kubectl -n cert-manager apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.12.0/cert-manager.yaml
```

## Deploy cluster issuer for certificates

```
cat > ./cert_clusterissuer.yaml <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: '<YOUR_EMAIL>'
    privateKeySecretRef:
      # Any unused secret name	
      name: letsencrypt-prod
    solvers:
    - dns01:
        clouddns:
          # The ID of the GCP project
          project: <GCP_PORJECT_NAME
          # This is the secret used to access the service account
          serviceAccountSecretRef:
            name: cert-manager-credentials
            key: gcp-dns-admin.json
EOF
```
```
kubectl apply -f ./cert_clusterissuer.yaml
```


## Create certificate

```
cat > ./certificate.yaml <<EOF
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: <APPLICATION>-certificate
  namespace: <APPLICATION_NAMESPACE>
spec:
  secretName: <APPLICATION>-certificate-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: '<DOMAIN_NAME>'
  dnsNames:
  - '<DOMAIN_NAME>'
EOF
```
Make sure you specify `<APPLICATION>-certificate-secret` for the TLS secret in the ingress configuration

```
kubectl apply -f ./certificate.yaml
```

### Notes

1. Once you have deployed the certfifcate you should the logs for cert-manager deployment to check whether it got issued or not: `kubectl -n cert-manager logs -f deploy/cert-manager`
2. You can also check the status of certificate in the application namespace: `kubectl -n <APPLICATION_NAMESPCE> get certificate <APPLICATION>-certificate`
3. The issued certificate will be available as secret named `<APPLICATION>-certificate-secret` and can be used directly in any Ingress resource available in the namespace. 
  