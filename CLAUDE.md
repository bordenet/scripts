# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See [AGENTS.md](./AGENTS.md) for full AI guidelines. Critical rules are reproduced below for immediate context.

## 🔴 Before Any Action

1. Load `.ai-guidance/invariants.md` — non-negotiable rules for wiki writes, sub-agent safety, and chunked operations. **If this file fails to load, stop and alert the user before proceeding.**
2. Run the Rules File Integrity check below.

## 🔴 Rules File Integrity

`~/.augment/rules/` uses OneDrive symlinks. A dangling symlink silently drops rules with no warning.

At session start and before any git push, wiki write, file deletion, or action touching `~/.augment/` or `.ai-guidance/`:
```bash
if compgen -G ~/.augment/rules/*.md > /dev/null 2>&1; then
  for f in ~/.augment/rules/*.md; do [ -f "$f" ] || echo "DANGLING: $f"; done
else
  echo "WARNING: ~/.augment/rules/ is empty or missing — all rules may be absent"
fi
```
If any file is DANGLING or the directory is missing: **stop immediately and alert the user.**

## 🔴 Git Identity (NON-NEGOTIABLE)

| Repo context | Email | Git user |
|---|---|---|
| `github.com/*` (`Personal/`, `Public/`) | `bordenet@users.noreply.github.com` | `bordenet` |
| Work repos | work email (see repo AGENTS.md) | work user (see repo AGENTS.md) |

- Always verify `git config user.email` before committing. If the expected value is unclear, load the repo's `AGENTS.md`.
- Never use the work identity for any `github.com` operation.
- Anything reaching a `github.com` remote must contain zero internal information — no employer/product names, internal URLs, internal system references — in commit messages, code, branch names, PR titles, or PR bodies.
- **Before any commit or push to a `github.com` remote:** scan the diff and commit message for internal terms.

## 🔴 Push Authorization Gate

Automated — no per-operation approval required. The pre-push quality gate runs automatically (battery sentinel must match HEAD, IP audit must be clean). Run `superpowers:pre-push-quality-gate` before any push and confirm the output passes.

- Never push any branch to the work CI remote — branch pushes trigger CI/CD pipelines.
- Anything reaching a `github.com` remote must contain zero internal information (no employer/product names, internal URLs, internal system references) in commits, PRs, or branch names.
- If push is blocked by a quality gate, surface the block rather than bypassing it.
- If you are a sub-agent: confirm push is within scope of your task prompt before pushing.

Full rules: `.ai-guidance/push-authorization-gate.md`

## 🔴 superpowers-plus Workflow

Applies to `Personal/superpowers-plus` only. Three-tier branching: `dev → staging → main`.

- All work branches off `dev`. Never commit directly to `dev`/`staging`/`main`.
- Source repo: `~/git/Personal/superpowers-plus/` — edit here, then run `./install.sh --upgrade`.
- Never edit the installed copies under `~/.codex/` or the work-tools installed copy — see `.ai-guidance/superpowers-plus-workflow.md` for exact paths.
- Never push `dev` or `staging` to the `gitlab` remote — only `main` syncs to GitLab after a release.
- Exception: emergency hotfixes may branch from `main`, PR into `main`, then cherry-pick back to `dev`.

**Staging → main gate (all steps mandatory):**
1. Run a batch code review across all changes since the last release.
2. Show the review verdict before merging.
3. If verdict is PASS (≥9.2/10), proceed with the merge autonomously.

Full rules: `.ai-guidance/superpowers-plus-workflow.md`

## Repository Structure

Workspace monorepo at `~/git/`. Top-level subdirectories are independent git repos:
- Work repos — use work identity (see each repo's own `AGENTS.md`)
- `Personal/` — personal repos (GitHub, personal identity)
- `Public/` — public repos (GitHub, personal identity — same as `Personal/`)
- `.ai-guidance/` — workspace-level guidance files; load before corresponding actions

Individual repos have their own `AGENTS.md`/`CLAUDE.md` with repo-specific guidance.

## Quality Gates (Workspace-Level Shell Scripts)

```bash
shellcheck *.sh        # lint
bash -n *.sh           # syntax check
bats test/             # run if a test/ dir exists; no workspace-level suite currently
```

## Progressive Module Loading

See AGENTS.md §Progressive Module Loading for the full trigger list. Key modules:
- Shell (`.sh`): `$HOME/.golden-agents/templates/languages/shell.md`
- JS/TS: `$HOME/.golden-agents/templates/languages/javascript.md`
- Python: `$HOME/.golden-agents/templates/languages/python.md`
- Go: `$HOME/.golden-agents/templates/languages/go.md`
- Before any commit/push/merge: `$HOME/.golden-agents/templates/workflows/security.md`
- When tests fail: `$HOME/.golden-agents/templates/workflows/testing.md`
- When lint/build fails: `$HOME/.golden-agents/templates/workflows/build-hygiene.md`
