# Scripts

A collection of utility scripts for various tasks.

## Script Index

| Script                                             | Description                                                                                                                                                           |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bu.sh`                                            | Performs a comprehensive system update and cleanup for a macOS environment.                                                                                           |
| `enumerate_gh_repos.sh`                            | Enumerates repositories within a specified GitHub Enterprise instance and organization.                                                                               |
| `fetch-github-projects.sh`                         | Automates the process of updating all local Git repositories located within a specified directory.                                                                    |
| `flush-dns-cache.sh`                               | Flushes the DNS cache on macOS.                                                                                                                                       |
| `get_active_repos.sh`                              | Identifies and lists active GitHub repositories within a specified organization.                                                                                      |
| `get_dormant_repos.sh`                             | Identifies and lists dormant GitHub repositories within a specified organization.                                                                                     |
| `npm-global-cleanup.sh`                            | Helps manage and clean up globally installed npm packages.                                                                                                            |
| `reset_all_repos.sh`                               | Automates the process of resetting multiple Git repositories to match their remote main/master branch.                                                                |
| `resume_claude.sh`                                 | Automates the process of resuming an AI assistant session with "Claude" within VS Code.                                                                               |
| `schedule_claude.sh`                               | Schedules the execution of the 'resume_claude.sh' script after a specified delay.                                                                                     |
| `scrub-git-history.sh`                             | Uses 'git-filter-repo' to rewrite the Git repository history, permanently removing specified files or directories from all commits.                                   |
| `setup_podman_for_terraform.sh`                    | Automates the setup and configuration of Podman to be used as a Docker-compatible environment for Terraform.                                                          |
| `squash_commits.sh`                                | Interactively squash a range of commits in a Git repository.                                                                                                          |
| `squash_last_n.sh`                                 | Squashes the last <N> commits into a single new commit using git reset --soft.                                                                                        |
| **inspection-sandbox/**                            |                                                                                                                                                                       |
| `inspection-sandbox/check-alpine-version.sh`       | Checks if the Alpine Linux version specified in the sandbox setup script is the latest stable version.                                                                |
| `inspection-sandbox/create-vm-alternate.sh`        | Provides an alternate method for creating the inspection sandbox VM.                                                                                                  |
| `inspection-sandbox/create-vm.sh`                  | Provides detailed manual instructions for creating the malware inspection sandbox VM using UTM.                                                                       |
| `inspection-sandbox/inspect.sh`                    | A wrapper for inspecting a suspicious file within the isolated malware analysis sandbox.                                                                              |
| `inspection-sandbox/provision-vm.sh`               | Helps automate the final provisioning steps for the inspection sandbox VM after Alpine Linux has been installed.                                                      |
| `inspection-sandbox/setup_alpine.sh`               | Executed INSIDE the Alpine Linux VM to perform an unattended installation.                                                                                            |
| `inspection-sandbox/setup_sandbox.sh`              | Sets up a secure sandbox environment for inspecting potentially malicious files.                                                                                      |
| `inspection-sandbox/status.sh`                     | Performs a comprehensive health check of the malware inspection sandbox environment.                                                                                  |
| `inspection-sandbox/shared/analyze.sh`             | Runs inside the Alpine Linux VM to analyze potentially malicious files.                                                                                               |
| **packet-capture/**                                |                                                                                                                                                                       |
| `packet-capture/capture.sh`                        | Starts a packet capture using tcpdump.                                                                                                                                |
| `packet-capture/compress-pcap-gzip.sh`             | Compresses .pcap files in a specified directory using gzip.                                                                                                           |
| `packet-capture/compress-pcap-zstd.sh`             | Compresses .pcap files in a specified directory using zstd.                                                                                                           |
| `packet-capture/start-pcap-rotate.sh`              | Starts a rotating packet capture using tcpdump.                                                                                                                       |
| `packet-capture/stop-pcap-rotate.sh`               | Stops the packet capture rotation process.                                                                                                                            |
| **secrets_in_source/**                             |                                                                                                                                                                       |
| `secrets_in_source/passhog_simple.sh`              | Performs a simplified scan for sensitive information (e.g., passwords, API keys) within files in a specified directory.                                               |