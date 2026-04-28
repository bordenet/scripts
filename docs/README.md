# Documentation Index

Detailed documentation for scripts and tools in this repository.

---

## Script Documentation

### Git & GitHub Tools

| Document | Script | Description |
|----------|--------|-------------|
| [sync-git-repos.md](./sync-git-repos.md) | [`sync-git-repos.sh`](../sync-git-repos.sh) | Parallel git sync wrapper — works with GitHub, GitLab, ADO, and local git; builds Go binary on demand |
| [integrate-claude-web-branch.md](./integrate-claude-web-branch.md) | [`integrate-claude-web-branch.sh`](../integrate-claude-web-branch.sh) | Integrates Claude Code web branches via complete PR workflow |
| [purge-stale-claude-code-web-branches.md](./purge-stale-claude-code-web-branches.md) | [`purge-stale-claude-code-web-branches.sh`](../purge-stale-claude-code-web-branches.sh) | Interactive tool to safely delete stale Claude Code web branches |

### System & Identity Tools

| Document | Script | Description |
|----------|--------|-------------|
| [purge-identity.md](./purge-identity.md) | [`purge-identity.sh`](../purge-identity.sh) | Comprehensive macOS identity purge — removes email traces from keychain, browsers, Mail |
| [tell-vscode-at.md](./tell-vscode-at.md) | [`tell-vscode-at.sh`](../tell-vscode-at.sh) | Send messages to VS Code instances at specified times via AppleScript |

---

## Guides & References

| Document | Purpose |
|----------|---------|
| [platform-detection-guide.md](./platform-detection-guide.md) | Detecting OS, architecture, and environment in shell scripts |

---

## Subdirectories

### `plans/`

Implementation plans, design documents, and review findings. Dated filenames (`YYYY-MM-DD-topic.md`) provide chronological context.

| Document | Description |
|----------|-------------|
| [2026-02-24-safe-merge-feature-branches-design.md](./plans/2026-02-24-safe-merge-feature-branches-design.md) | Design for safe feature-branch merge strategy |
| [2026-02-24-safe-merge-implementation-plan.md](./plans/2026-02-24-safe-merge-implementation-plan.md) | Implementation plan for safe merges |
| [2026-04-11-gitsync-review-findings.md](./plans/2026-04-11-gitsync-review-findings.md) | Code-review-battery findings for gitsync (April 2026) |

### `superpowers/`

AI-assisted planning artifacts for the gitsync Go implementation. Not end-user documentation.

| Document | Description |
|----------|-------------|
| [superpowers/specs/2026-04-09-gitsync-design.md](./superpowers/specs/2026-04-09-gitsync-design.md) | gitsync architecture spec |
| [superpowers/plans/2026-04-10-gitsync-implementation.md](./superpowers/plans/2026-04-10-gitsync-implementation.md) | gitsync implementation plan |

---

## Related Documentation

- **[../README.md](../README.md)** — Repository overview and script catalog
- **[../STYLE_GUIDE.md](../STYLE_GUIDE.md)** — Shell script coding standards (authoritative)
- **[../AGENTS.md](../AGENTS.md)** — AI assistant guidelines
- **[../starter-kit/](../starter-kit/)** — Portable engineering best practices for new projects

---

**Last Updated**: 2026-04-11
