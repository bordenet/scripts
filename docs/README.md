# Documentation Index

This directory contains detailed documentation for scripts and tools in this repository.

## Table of Contents

- [Script Documentation](#script-documentation)
- [Guides & References](#guides--references)

---

## Script Documentation

Detailed usage guides for specific scripts:

### Git & GitHub Tools

| Document | Script | Description |
|----------|--------|-------------|
| [fetch-github-projects.md](./fetch-github-projects.md) | [`fetch-github-projects.sh`](../fetch-github-projects.sh) | Automates updating all local Git repositories in a directory |
| [integrate-claude-web-branch.md](./integrate-claude-web-branch.md) | [`integrate-claude-web-branch.sh`](../integrate-claude-web-branch.sh) | Integrates Claude Code web branches via complete PR workflow |
| [purge-stale-claude-code-web-branches.md](./purge-stale-claude-code-web-branches.md) | [`purge-stale-claude-code-web-branches.sh`](../purge-stale-claude-code-web-branches.sh) | Interactive tool to safely delete stale Claude Code web branches |

### System & Identity Tools

| Document | Script | Description |
|----------|--------|-------------|
| [purge-identity.md](./purge-identity.md) | [`purge-identity.sh`](../purge-identity.sh) | Comprehensive macOS identity purge tool for removing email traces |

---

## Guides & References

Technical guides and reference materials:

| Document | Purpose | Audience |
|----------|---------|----------|
| [platform-detection-guide.md](./platform-detection-guide.md) | Comprehensive guide for detecting OS, architecture, and environment in shell scripts | Script developers |

---

## Related Documentation

For repository-wide standards and guidelines, see:

- **[../README.md](../README.md)** - Repository overview and script catalog
- **[../STYLE_GUIDE.md](../STYLE_GUIDE.md)** - Shell script coding standards (authoritative)
- **[../CLAUDE.md](../CLAUDE.md)** - Guidelines for AI assistants working in this repository
- **[../starter-kit/](../starter-kit/)** - Portable engineering best practices for new projects

---

## Contributing Documentation

When adding new documentation:

1. **Create the document** in the appropriate location:
   - Script-specific docs: `docs/<script-name>.md`
   - Planning docs: `docs/plans/<date>-<topic>.md`
   - Guides: `docs/<topic>-guide.md`

2. **Update this index** with:
   - Link to the document
   - Brief description
   - Related script (if applicable)
   - Target audience (if a guide)

3. **Cross-reference** from:
   - Main README.md (if script documentation)
   - Related scripts (in header comments)
   - STYLE_GUIDE.md (if relevant to standards)

4. **Follow documentation standards**:
   - Use clear, concise language
   - Include table of contents for docs > 100 lines
   - Provide examples where applicable
   - Keep language professional and factual

---

## Documentation Standards

All documentation in this repository follows these principles:

- **Clarity**: Write for the reader who knows nothing about the topic
- **Precision**: Use exact, factual language without marketing hype
- **Completeness**: Cover all important aspects, edge cases, and gotchas
- **Maintainability**: Keep docs up-to-date when code changes
- **Cross-referencing**: Link to related docs and code

---

**Last Updated**: 2025-11-29
