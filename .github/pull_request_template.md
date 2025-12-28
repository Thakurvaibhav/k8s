## Description

<!-- Provide a clear and concise description of what this PR changes and why -->

## Type of Change

<!-- Mark the relevant option with an 'x' -->

- [ ] New component/chart
- [ ] Chart update/enhancement
- [ ] Values file update
- [ ] Documentation update
- [ ] Bug fix
- [ ] Security fix
- [ ] CI/CD improvement
- [ ] Other (please describe): ___________

## Affected Components

<!-- List which charts/components are affected by this change -->

- [ ] app-of-apps
- [ ] cert-manager
- [ ] envoy-gateway
- [ ] external-dns
- [ ] kyverno
- [ ] logging (elastic-stack)
- [ ] monitoring
- [ ] nginx-ingress-controller
- [ ] redis
- [ ] sealed-secrets
- [ ] jaeger
- [ ] Other: ___________

## Environment Impact

<!-- Mark which environments are affected by this change -->

- [ ] dev-01
- [ ] stag-01
- [ ] prod-01
- [ ] ops-01
- [ ] All environments
- [ ] Documentation only (no cluster impact)


## Testing

<!-- Describe what testing was performed -->

- [ ] Helm template rendering tested (`helm template`)
- [ ] Helm lint passed (`helm lint`)
- [ ] Chart scan passed (`scripts/scan.sh lint`)
- [ ] Trivy scan passed (`scripts/scan.sh trivy`)
- [ ] Checkov scan passed (`scripts/scan.sh checkov`)
- [ ] Tested in dev cluster
- [ ] Manual testing performed (describe below)
- [ ] No testing required (documentation only)

**Testing details:** <!-- Describe any manual testing or validation performed -->

## Breaking Changes

<!-- Does this PR introduce breaking changes? -->

- [ ] No breaking changes
- [ ] Breaking changes (describe below)

**Breaking changes description:** <!-- If yes, describe what breaks and migration steps -->

## Checklist

<!-- Mark completed items with an 'x' -->

### Code Quality
- [ ] Code follows repository conventions
- [ ] Chart version bumped (if chart changes)
- [ ] Values files updated for all affected environments
- [ ] No hardcoded values or secrets
- [ ] Sealed secrets used for sensitive data (if applicable)

### Documentation
- [ ] README.md updated (if component changes)
- [ ] Chart README.md updated (if chart changes)
- [ ] ADR created/updated (if architectural decision)
- [ ] `docs/` updated (if operational procedures change)
- [ ] Comments added to complex code/templates

### Security & Compliance
- [ ] No secrets committed in plaintext
- [ ] Security scanning passed (Trivy, Checkov)
- [ ] Kyverno policies considered (if applicable)

### CI/CD
- [ ] Chart scan passes locally
- [ ] All CI checks expected to pass
- [ ] No temporary workarounds or TODOs left in code

## Related Issues/PRs

<!-- Link related issues or PRs -->

- Closes #___________
- Related to #___________
- Supersedes #___________

## Additional Context

<!-- Add any other context, screenshots, or information that would help reviewers -->

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on? -->

