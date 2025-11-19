# Scripts

A collection of utility scripts for various tasks.

## Git & GitHub

| Script | Description |
|---|---|
| [`enumerate-gh-repos.sh`](./enumerate-gh-repos.sh) | Enumerates repositories within a specified GitHub Enterprise instance and organization. |
| [`fetch-github-projects.sh`](./fetch-github-projects.sh) | Automates the process of updating all local Git repositories located within a specified directory. [Docs](./docs/fetch-github-projects.md) |
| [`integrate-claude-web-branch.sh`](./integrate-claude-web-branch.sh) | Integrates Claude Code web branches into main via complete PR workflow with minimal output. [Docs](./docs/integrate-claude-web-branch.md) |
| [`purge-stale-claude-code-web-branches.sh`](./purge-stale-claude-code-web-branches.sh) | Interactive tool to safely delete stale Claude Code web branches with human-readable timestamps. [Docs](./docs/purge-stale-claude-code-web-branches.md) |
| [`get-active-repos.sh`](./get-active-repos.sh) | Identifies and lists active GitHub repositories within a specified organization. |
| [`list-dormant-repos.sh`](./list-dormant-repos.sh) | Identifies and lists dormant GitHub repositories within a specified organization. |
| [`reset-all-repos.sh`](./reset-all-repos.sh) | Automates the process of resetting multiple Git repositories to match their remote main/master branch. |
| [`scrub-git-history.sh`](./scrub-git-history.sh) | Uses 'git-filter-repo' to rewrite the Git repository history, permanently removing specified files or directories from all commits. |
| [`squash-commits.sh`](./squash-commits.sh) | Interactively squash a range of commits in a Git repository. |
| [`squash-last-n.sh`](./squash-last-n.sh) | Squashes the last <N> commits into a single new commit using git reset --soft. |

## System & Environment

| Script | Description |
|---|---|
| [`bu.sh`](./bu.sh) | Performs a comprehensive system update and cleanup for a macOS environment. |
| [`flush-dns-cache.sh`](./flush-dns-cache.sh) | Flushes the DNS cache on macOS. |
| [`cleanup-npm-global.sh`](./cleanup-npm-global.sh) | Helps manage and clean up globally installed npm packages. |
| [`purge-identity.sh`](./purge-identity.sh) | Comprehensive macOS identity purge tool that discovers and permanently removes all traces of specified email identities from the system (keychain, browsers, Mail.app, SSH keys, cloud storage). |
| [`setup-podman-for-terraform.sh`](./setup-podman-for-terraform.sh) | Automates the setup and configuration of Podman to be used as a Docker-compatible environment for Terraform. |

## Security & Analysis

| Script | Description |
|---|---|
| [`analyze-malware-sandbox/check-alpine-version.sh`](./analyze-malware-sandbox/check-alpine-version.sh) | Checks if the Alpine Linux version specified in the sandbox setup script is the latest stable version. |
| [`analyze-malware-sandbox/create-vm-alternate.sh`](./analyze-malware-sandbox/create-vm-alternate.sh) | Provides an alternate method for creating the inspection sandbox VM. |
| [`analyze-malware-sandbox/create-vm.sh`](./analyze-malware-sandbox/create-vm.sh) | Provides detailed manual instructions for creating the malware inspection sandbox VM using UTM. |
| [`analyze-malware-sandbox/inspect.sh`](./analyze-malware-sandbox/inspect.sh) | A wrapper for inspecting a suspicious file within the isolated malware analysis sandbox. |
| [`analyze-malware-sandbox/provision-vm.sh`](./analyze-malware-sandbox/provision-vm.sh) | Helps automate the final provisioning steps for the inspection sandbox VM after Alpine Linux has been installed. |
| [`analyze-malware-sandbox/setup-alpine.sh`](./analyze-malware-sandbox/setup-alpine.sh) | Executed INSIDE the Alpine Linux VM to perform an unattended installation. |
| [`analyze-malware-sandbox/setup-sandbox.sh`](./analyze-malware-sandbox/setup-sandbox.sh) | Sets up a secure sandbox environment for inspecting potentially malicious files. |
| [`analyze-malware-sandbox/status.sh`](./analyze-malware-sandbox/status.sh) | Performs a comprehensive health check of the malware inspection sandbox environment. |
| [`analyze-malware-sandbox/shared/analyze.sh`](./analyze-malware-sandbox/shared/analyze.sh) | Runs inside the Alpine Linux VM to analyze potentially malicious files. |
| [`capture-packets/capture.sh`](./capture-packets/capture.sh) | Starts a packet capture using tcpdump. |
| [`capture-packets/compress-pcap-gzip.sh`](./capture-packets/compress-pcap-gzip.sh) | Compresses .pcap files in a specified directory using gzip. |
| [`capture-packets/compress-pcap-zstd.sh`](./capture-packets/compress-pcap-zstd.sh) | Compresses .pcap files in a specified directory using zstd. |
| [`capture-packets/start-pcap-rotate.sh`](./capture-packets/start-pcap-rotate.sh) | Starts a rotating packet capture using tcpdump. |
| [`capture-packets/stop-pcap-rotate.sh`](./capture-packets/stop-pcap-rotate.sh) | Stops the packet capture rotation process. |

## Xcode

| Script | Description |
|---|---|
| [`xcode/inspect-xcode.sh`](./xcode/inspect-xcode.sh) | Analyzes an Xcode project for common issues. |

## AI Assistant

| Script | Description |
|---|---|
| [`resume-claude.sh`](./resume-claude.sh) | Automates the process of resuming an AI assistant session with "Claude" within VS Code. |
| [`schedule-claude.sh`](./schedule-claude.sh) | Schedules the execution of the 'resume-claude.sh' script after a specified delay. |

## Engineering Starter Kit

Portable collection of engineering best practices for new projects.

See **[`starter-kit/`](./starter-kit/README.md)** for:
- Pre-commit hooks, validation systems, dependency management
- AI development protocols for Claude Code
- Cross-language style guides (Go, JS/TS, Dart, Kotlin, Swift)
- Reusable shell script library (common.sh)
- Project setup checklist

```bash
# Copy to your project
cp -r starter-kit/ your-project/docs/
```

---

## macOS Development Environment Setup

Modular, component-based architecture for macOS setup scripts.

See **[`macos-setup/`](./macos-setup/README.md)** for reusable template system with:
- Component-based architecture (reduces complexity ~65%)
- Selective component reuse
- Consistent UI (verbose/compact modes)
- AI-assisted customization guide

```bash
# Copy to your project
cp -r macos-setup/lib your-project/scripts/
cp -r macos-setup/setup-components your-project/scripts/
cp macos-setup/setup-macos-template.sh your-project/scripts/setup-macos.sh
