# Scripts

A collection of utility scripts for various tasks.

## Git & GitHub

| Script | Description |
|---|---|
| [`enumerate_gh_repos.sh`](./enumerate_gh_repos.sh) | Enumerates repositories within a specified GitHub Enterprise instance and organization. |
| [`fetch-github-projects.sh`](./fetch-github-projects.sh) | Automates the process of updating all local Git repositories located within a specified directory. |
| [`get_active_repos.sh`](./get_active_repos.sh) | Identifies and lists active GitHub repositories within a specified organization. |
| [`get_dormant_repos.sh`](./get_dormant_repos.sh) | Identifies and lists dormant GitHub repositories within a specified organization. |
| [`reset_all_repos.sh`](./reset_all_repos.sh) | Automates the process of resetting multiple Git repositories to match their remote main/master branch. |
| [`scrub-git-history.sh`](./scrub-git-history.sh) | Uses 'git-filter-repo' to rewrite the Git repository history, permanently removing specified files or directories from all commits. |
| [`squash_commits.sh`](./squash_commits.sh) | Interactively squash a range of commits in a Git repository. |
| [`squash_last_n.sh`](./squash_last_n.sh) | Squashes the last <N> commits into a single new commit using git reset --soft. |

## System & Environment

| Script | Description |
|---|---|
| [`bu.sh`](./bu.sh) | Performs a comprehensive system update and cleanup for a macOS environment. |
| [`flush-dns-cache.sh`](./flush-dns-cache.sh) | Flushes the DNS cache on macOS. |
| [`npm-global-cleanup.sh`](./npm-global-cleanup.sh) | Helps manage and clean up globally installed npm packages. |
| [`setup_podman_for_terraform.sh`](./setup_podman_for_terraform.sh) | Automates the setup and configuration of Podman to be used as a Docker-compatible environment for Terraform. |

## Security & Analysis

| Script | Description |
|---|---|
| [`inspection-sandbox/check-alpine-version.sh`](./inspection-sandbox/check-alpine-version.sh) | Checks if the Alpine Linux version specified in the sandbox setup script is the latest stable version. |
| [`inspection-sandbox/create-vm-alternate.sh`](./inspection-sandbox/create-vm-alternate.sh) | Provides an alternate method for creating the inspection sandbox VM. |
| [`inspection-sandbox/create-vm.sh`](./inspection-sandbox/create-vm.sh) | Provides detailed manual instructions for creating the malware inspection sandbox VM using UTM. |
| [`inspection-sandbox/inspect.sh`](./inspection-sandbox/inspect.sh) | A wrapper for inspecting a suspicious file within the isolated malware analysis sandbox. |
| [`inspection-sandbox/provision-vm.sh`](./inspection-sandbox/provision-vm.sh) | Helps automate the final provisioning steps for the inspection sandbox VM after Alpine Linux has been installed. |
| [`inspection-sandbox/setup_alpine.sh`](./inspection-sandbox/setup_alpine.sh) | Executed INSIDE the Alpine Linux VM to perform an unattended installation. |
| [`inspection-sandbox/setup_sandbox.sh`](./inspection-sandbox/setup_sandbox.sh) | Sets up a secure sandbox environment for inspecting potentially malicious files. |
| [`inspection-sandbox/status.sh`](./inspection-sandbox/status.sh) | Performs a comprehensive health check of the malware inspection sandbox environment. |
| [`inspection-sandbox/shared/analyze.sh`](./inspection-sandbox/shared/analyze.sh) | Runs inside the Alpine Linux VM to analyze potentially malicious files. |
| [`packet-capture/capture.sh`](./packet-capture/capture.sh) | Starts a packet capture using tcpdump. |
| [`packet-capture/compress-pcap-gzip.sh`](./packet-capture/compress-pcap-gzip.sh) | Compresses .pcap files in a specified directory using gzip. |
| [`packet-capture/compress-pcap-zstd.sh`](./packet-capture/compress-pcap-zstd.sh) | Compresses .pcap files in a specified directory using zstd. |
| [`packet-capture/start-pcap-rotate.sh`](./packet-capture/start-pcap-rotate.sh) | Starts a rotating packet capture using tcpdump. |
| [`packet-capture/stop-pcap-rotate.sh`](./packet-capture/stop-pcap-rotate.sh) | Stops the packet capture rotation process. |
| [`secrets_in_source/passhog_simple.sh`](./secrets_in_source/passhog_simple.sh) | **DEPRECATED.** Performs a simplified scan for sensitive information (e.g., passwords, API keys) within files in a specified directory. Successor project: https://github.com/bordenet/secrets-in-source |

## AI Assistant

| Script | Description |
|---|---|
| [`resume_claude.sh`](./resume_claude.sh) | Automates the process of resuming an AI assistant session with "Claude" within VS Code. |
| [`schedule_claude.sh`](./schedule_claude.sh) | Schedules the execution of the 'resume_claude.sh' script after a specified delay. |

## macOS Development Environment Setup

**NEW**: Modular, component-based architecture for maintainable macOS setup scripts.

See **[`macos-setup/`](./macos-setup/README.md)** for a reusable template system that:
- ✅ Reduces setup script complexity by ~65%
- ✅ Enables selective component reuse across projects
- ✅ Provides consistent UI (verbose/compact modes)
- ✅ Includes comprehensive adoption guide for AI-assisted customization

**Quick Start:**
```bash
# Copy to your project
cp -r macos-setup/lib your-project/scripts/
cp -r macos-setup/setup-components your-project/scripts/
cp macos-setup/setup-macos-template.sh your-project/scripts/setup-macos.sh

# See ./macos-setup/README.md for detailed documentation and customization guide
