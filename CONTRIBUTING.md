# Contributing

Contributions are welcome!

Please carefully read this page to make the code review process go as smoothly as possible and to maximize the likelihood of your contribution being merged.

## Bug Reports

For bug reports or feature requests, submit an [issue](https://github.com/Thakurvaibhav/k8s/issues/new/choose).

## Pull Requests

The preferred way to contribute is to fork the main repository on GitHub.

1. **Fork the main repository.** Click on the 'Fork' button near the top of the page. This creates a copy of the code under your account on the GitHub server.

2. **Clone this copy to your local disk:**
   ```bash
   git clone git@github.com:YourLogin/k8s.git
   cd k8s
   ```

3. **Create a branch to hold your changes and start making changes.** Don't work in the `dev` branch directly!
   ```bash
   git checkout -b my-feature
   ```

4. **Work on this copy on your computer using Git to do the version control.** When you're done editing, run the following to record your changes in Git:
   ```bash
   git add modified_files
   git commit
   ```

5. **Push your changes to GitHub with:**
   ```bash
   git push -u origin my-feature
   ```

6. **Finally, go to the web page of your fork of the k8s repo and click 'Pull Request' to send your changes for review.**

If you are not familiar with pull requests, review the [GitHub Pull Requests Docs](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests).

## Important Guidelines

### Before Submitting

**Test your changes:**
```bash
# Template rendering
helm template charts/<component> -f charts/<component>/values.dev-01.yaml

# Linting
helm lint charts/<component>

# Security scanning
scripts/scan.sh lint
scripts/scan.sh trivy
scripts/scan.sh checkov
```

**Security:**
- Never commit plaintext secrets - use `kubeseal` to encrypt before committing
- All container images must pass Trivy scanning
- Charts must pass Checkov security scanning

**Documentation:**
- Update chart `README.md` for component changes
- Update main `README.md` Inventory table if adding components
- Create/update ADRs for significant architectural decisions

## Additional Resources

- [AGENTS.md](AGENTS.md) - Repository conventions and structure
- [README.md](README.md) - Platform overview and inventory
- [SECURITY.md](SECURITY.md) - Security policy and practices
- [Architecture Decision Records](docs/adr/) - Design decisions and rationale
- [FAQ](docs/faq.md) - Common questions and answers
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions

