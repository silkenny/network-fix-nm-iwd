# Contributing to Network Fix: NetworkManager & iwd

Thank you for your interest in contributing to this project! This guide will help you get started.

## 🚀 Quick Start

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/network-fix-nm-iwd.git`
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## 🧪 Testing

### Local Testing

Before submitting changes, please test on multiple distributions:

**Required Tests:**
- Test on a clean system with both NetworkManager and iwd installed
- Verify the fix works correctly
- Test the restore functionality
- Check the status script provides accurate information

**Testing Script:**
```bash
# Test the fix
sudo ./fix-network.sh

# Verify functionality
./check-status.sh
nmcli device wifi list

# Test restoration
sudo ./restore-network.sh

# Verify restoration
./check-status.sh
```

### Test Environments

Please test on at least one of these distributions:
- Arch Linux
- Fedora 38+
- Ubuntu 22.04+
- openSUSE Tumbleweed

### Virtual Machine Testing

For safety, use virtual machines with Wi-Fi passthrough or USB Wi-Fi adapters for testing.

## 📝 Code Standards

### Bash Scripting Guidelines

1. **Use strict mode**: `set -euo pipefail`
2. **Quote variables**: Use `"$variable"` instead of `$variable`
3. **Check command existence**: Use `command -v cmd` before using commands
4. **Handle errors gracefully**: Implement proper error handling and cleanup
5. **Use meaningful function names**: Functions should be self-documenting
6. **Comment complex logic**: Explain why, not what

### Style Guide

- **Indentation**: 4 spaces (no tabs)
- **Line length**: Maximum 100 characters
- **Function naming**: Use snake_case for functions
- **Variable naming**: Use snake_case for variables
- **Constants**: Use UPPER_CASE for constants

### Example Code Style

```bash
#!/bin/bash
set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/logs/operation.log"

# Function with proper error handling
backup_configuration() {
    local config_file="$1"
    local backup_name="$2"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi
    
    if ! cp "$config_file" "${BACKUP_DIR}/${backup_name}.backup"; then
        log_error "Failed to backup $config_file"
        return 1
    fi
    
    log_info "Successfully backed up $config_file"
    return 0
}
```

## 🐛 Bug Reports

When reporting bugs, please include:

### System Information
- Distribution and version
- Kernel version (`uname -r`)
- NetworkManager version (`nmcli --version`)
- iwd version (if available)

### Reproduction Steps
1. Clear steps to reproduce the issue
2. Expected behavior
3. Actual behavior
4. Any error messages

### Logs
Please attach relevant logs:
- Script logs from `./logs/` directory
- System logs: `journalctl -u NetworkManager --since "1 hour ago"`
- System logs: `journalctl -u iwd --since "1 hour ago"`

### Bug Report Template

```markdown
**System Information:**
- OS: [e.g., Arch Linux]
- Kernel: [e.g., 6.1.0]
- NetworkManager version: [e.g., 1.44.0]

**Bug Description:**
A clear description of the bug.

**Steps to Reproduce:**
1. Step one
2. Step two
3. Step three

**Expected Behavior:**
What should happen.

**Actual Behavior:**
What actually happens.

**Logs:**
```
[Paste relevant logs here]
```
```

## 💡 Feature Requests

### Before Requesting
- Check existing issues to avoid duplicates
- Consider if the feature fits the project scope
- Think about backward compatibility

### Feature Request Template

```markdown
**Feature Description:**
Clear description of the proposed feature.

**Use Case:**
Why is this feature needed? What problem does it solve?

**Proposed Implementation:**
Ideas for how this could be implemented.

**Alternatives Considered:**
Other approaches you've thought about.
```

## 🔧 Development Setup

### Prerequisites
- Linux system (preferably in a VM for testing)
- Bash 4.0+
- NetworkManager
- iwd (for testing conflicts)
- Basic system utilities (systemctl, nmcli, etc.)

### Development Environment

```bash
# Clone the repository
git clone https://github.com/silkenny/network-fix-nm-iwd.git
cd network-fix-nm-iwd

# Make scripts executable
chmod +x *.sh

# Create development branch
git checkout -b feature/your-feature

# Set up pre-commit hooks (optional)
ln -s ../../scripts/pre-commit .git/hooks/pre-commit
```

## 📋 Pull Request Process

### Before Submitting

1. **Test thoroughly** on multiple distributions
2. **Update documentation** if needed
3. **Add/update comments** for new code
4. **Follow the coding standards**
5. **Ensure scripts are executable**

### Pull Request Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on Arch Linux
- [ ] Tested on Fedora
- [ ] Tested on Ubuntu
- [ ] Fix functionality verified
- [ ] Restore functionality verified
- [ ] Status check accuracy verified

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)
```

### Review Process

1. **Automated checks** (if applicable)
2. **Manual code review**
3. **Testing verification**
4. **Documentation review**
5. **Final approval and merge**

## 📚 Documentation

### What to Document

- New features or significant changes
- Configuration options
- Troubleshooting steps
- Compatibility information

### Documentation Standards

- Use clear, concise language
- Include examples where helpful
- Keep README.md up to date
- Comment complex code sections

## 🎯 Areas for Contribution

### High Priority
- Support for additional distributions
- Improved error handling and recovery
- Enhanced logging and diagnostics
- Performance optimizations

### Medium Priority
- GUI wrapper for the scripts
- Configuration file support
- Integration with system package managers
- Automated testing framework

### Low Priority
- Additional network backend support
- Advanced configuration options
- Monitoring and alerting features

## 🤝 Community Guidelines

### Be Respectful
- Use inclusive language
- Be patient with newcomers
- Provide constructive feedback
- Help others learn

### Be Collaborative
- Share knowledge and experience
- Ask questions when unsure
- Offer help on issues and PRs
- Participate in discussions

## 📞 Getting Help

### Channels
- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Request Comments**: Code-specific discussions

### Response Times
- We aim to respond to issues within 48-72 hours
- Pull requests may take 3-7 days for initial review
- Complex changes may require longer review periods

## 🏆 Recognition

Contributors will be:
- Listed in the project README
- Mentioned in release notes for significant contributions
- Invited to become maintainers for substantial ongoing contributions

## 📄 License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project.
