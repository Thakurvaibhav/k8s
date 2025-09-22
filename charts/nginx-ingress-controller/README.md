# nginx-ingress-controller Helm Chart

## Overview
Deploys an NGINX Ingress Controller customized per environment.

## Features
- Environment specific overrides (`values.*.yaml`)
- Base controller installation

## Configuration
Tune controller settings, service type, TLS, and ingress class in the values files.

## Deploy
```bash
helm upgrade --install nginx-ingress-controller ./nginx-ingress-controller -f values.dev-01.yaml -n ingress-nginx
```

## Prerequisites
- Kubernetes v1.25+

## Notes
- Ensure DNS records map to the Service LoadBalancer external IP for exposed hosts.
