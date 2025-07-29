# AWS Reference Implementation

Thank you for your interest in contributing to the AWS Reference Implementation! This guide will help you get started with contributing to this Internal Developer Platform (IDP) reference implementation for AWS.

## Getting Started

### Prerequisites

Before contributing, ensure you have the following tools installed:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [yq](https://mikefarah.gitbook.io/yq/v3.x)
- [helm](https://helm.sh/docs/intro/install/)
- [Git](https://git-scm.com/downloads)

### Development Environment Setup

1. Fork the repository to your GitHub organization
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-org/reference-implementation-aws.git
   cd reference-implementation-aws
   ```
3. Set up your development environment following the [Getting Started](README.md#getting-started) guide

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or request features
- Search existing issues before creating new ones
- Provide detailed information including:
  - Steps to reproduce
  - Expected vs actual behavior
  - Environment details (AWS region, EKS version, etc.)
  - Relevant logs or error messages

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the project structure:
   - **Addons**: Add new addons in `packages/` directory
   - **Scripts**: Update installation/management scripts in `scripts/`
   - **Documentation**: Update docs in `docs/` directory
   - **Templates**: Add Backstage templates in `templates/`
   - **Examples**: Add usage examples in `examples/`

3. Test your changes:
   ```bash
   # Test installation
   ./scripts/install.sh
   
   # Verify addons are healthy
   kubectl get applications -n argocd
   ```

4. Commit your changes:
   ```bash
   git add .
   git commit -m "feat: add new addon for X"
   ```

5. Push and create a pull request:
   ```bash
   git push origin feature/your-feature-name
   ```

## Project Structure

```
├── cluster/         # EKS cluster configurations (eksctl/terraform)
├── docs/            # Documentation and images
├── examples/        # Usage examples and demos
├── packages/        # Helm charts and addon configurations
├── private/         # GitHub App credentials (templates)
├── scripts/         # Installation and management scripts
├── templates/       # Backstage templates
└── config.yaml      # Main configuration file
```

## Adding New Addons

To add a new addon:

1. Create a directory in `packages/your-addon/`
2. Add `values.yaml` with Helm chart configuration
3. Update `packages/addons/values.yaml` to include your addon
4. Add documentation in `docs/` if needed
5. Test the addon installation

## Code Standards

- Follow existing code style and patterns
- Use meaningful commit messages (conventional commits preferred)
- Update documentation for any user-facing changes
- Ensure scripts are executable and include proper error handling
- Test changes in a real EKS environment when possible

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include tests or validation steps
- Update relevant documentation
- Reference related issues in PR description
- Ensure CI checks pass

## Testing

Before submitting:

1. Test the full installation flow:
   ```bash
   ./scripts/install.sh
   ```

2. Verify all addons are healthy:
   ```bash
   kubectl get applications -n argocd
   ```

3. Test cleanup process:
   ```bash
   ./scripts/uninstall.sh
   ```

## Documentation

- Update README.md for user-facing changes
- Add or update documentation in `docs/` directory
- Include examples in `examples/` directory when applicable
- Update configuration tables and addon lists as needed

## Getting Help

- Check existing [documentation](docs/)
- Review [troubleshooting guide](docs/troubleshooting.md)
- Open an issue for questions or problems
- Join community discussions in GitHub Discussions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.