# app-of-apps Helm Chart

## Overview
Implements an Argo CD "App of Apps" pattern to bootstrap multiple application/infra charts from a single root.

## Features
- Central orchestration of environment application set
- Environment specific values overrides
- Simplifies onboarding and promotion flows

## Usage
Define child Applications or Projects under `templates/`. Each environment file (`values.*.yaml`) can toggle inclusions or set sources.

## Deploy
```bash
helm upgrade --install app-of-apps ./app-of-apps -f values.dev-01.yaml -n argocd
```

## Recommended
- Use sync waves and hooks in child apps for ordering
- Lock chart versions for reproducibility
