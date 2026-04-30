# superpowers-plus: Dev → Staging → Production (NON-NEGOTIABLE)

`superpowers-plus` uses a three-tier branching model on GitHub with a private fork sync.

| Branch | Purpose | Accepts PRs from | Merges into | Cadence |
|--------|---------|-------------------|-------------|---------|
| `dev` | Active development | Feature/fix branches | `staging` | Frequent — per feature/fix |
| `staging` | Batch validation | `dev` only | `main` | Deliberate — accumulate many changes |
| `main` | Production releases | `staging` only | Private fork sync | **Rare — explicit human decision** |

**Feature flow:**

```bash
# 1. Branch from dev — ALL work starts here
git fetch origin
git checkout -b feat/my-feature origin/dev
# ... make changes, commit, battery review ...
git push origin feat/my-feature
# Create PR on GitHub targeting dev → merge

# 2. Accumulate changes in dev until a meaningful batch is ready.
#    DO NOT promote to staging after every feature.

# 3. Promote dev → staging after multiple verified changes are accumulated in dev

# 4. Promote staging → main after a batch code review passes (≥9.2/10)

# 5. Sync private fork AFTER production merge
git checkout main && git pull origin main && git push gitlab main
```

## 🔴 Source Repos vs Installed Files (NON-NEGOTIABLE)

| Location | Role | Editable? |
|----------|------|-----------|
| `~/git/Personal/superpowers-plus/` | **Source repo** — GitHub PR workflow | ✅ YES — edit HERE |
| `~/git/[COMPANY]/superpowers-[removed]/` | **Source repo** — private overlay | ✅ YES — edit here |
| `~/.codex/superpowers-plus/` | **Installed copy** — deployment target | ❌ NEVER |
| `~/.codex/skills/` | **Installed skills** — deployment target | ❌ NEVER |
| `~/git/[COMPANY]/tools/superpowers-plus/` | **Installed copy** — [COMPANY] deployment | ❌ NEVER |

**Workflow:** Edit source repo → run `./install.sh --upgrade` → changes propagate to `~/.codex/`.

- ❌ **NEVER** edit files under `~/.codex/` directly
- ❌ **NEVER** edit `~/git/[COMPANY]/tools/superpowers-plus/` — it is a deployment target, not a working directory
- ❌ **NEVER** commit anywhere except `~/git/Personal/superpowers-plus/`
- ✅ To test a local change before opening a PR: edit the source repo, re-run install, verify in `~/.codex/`

**Detection:** `sp-doctor` flags CRITICAL when `~/.codex/superpowers-plus` has local commits not on origin.

---

**Prohibitions:**
- ❌ **NEVER** commit directly to `dev`, `staging`, or `main` — always use a branch + PR
- ❌ **NEVER** branch features from `main` or `staging` (branch from `dev`)
- ❌ **NEVER** push `dev` or `staging` to the private fork — only `main` is synced
- ❌ **NEVER** skip the private fork sync after a production merge
- ❌ **NEVER** promote `dev → staging` prematurely — staging accumulates multiple verified changes before main
- ❌ **NEVER** treat a single feature landing in `dev` as a reason to promote — staging must accumulate multiple verified changes
- ✅ **Exception:** Emergency hotfixes may branch from `main`, PR into `main`, then cherry-pick back to `dev`

**Staging → Main gate (MANDATORY before any promotion):**
1. Run a batch code review across ALL changes in staging since the last main release
2. Show the review verdict before merging
3. If verdict is PASS (≥9.2/10), proceed with the merge autonomously

| Date | Incident |
|------|----------|
| 2026-03-24 | Agent edited directly on private fork instead of GitHub PR. |
| 2026-03-25 | Agent pushed to private fork first, then tried GitHub. Violated GitHub-first policy. |
| 2026-03-25 | Bulk wiki update destroyed 5 pages. New invariant: verify every write. |
| 2026-03-28 | Migrated from two-tier (main + sync) to three-tier (dev → staging → main). |
| 2026-03-30 | Agent repeatedly edited `~/.codex/superpowers-plus/` directly, creating stray commits with wrong git identity that were never on GitHub. Stale fork + wrong-author commits required force-reset. |
| 2026-04-03 | Agent operated against `~/git/[COMPANY]/tools/superpowers-plus/` ([COMPANY] deployment target) instead of `~/git/Personal/superpowers-plus/`. Committed and pushed directly to staging from the wrong repo. Required manual sync to fix. |
| 2026-04-14 | Agent pushed `dev` and `staging` branches to `gitlab` remote (only `main` is permitted). Root cause: `superpowers.always.md` rule file was deleted from OneDrive and replaced with a pull-only module, removing auto-injected GitLab restrictions from context. |
| 2026-04-14 | Agent included [COMPANY]-internal details in commit messages pushed to public `github.com/bordenet/superpowers-plus`. IP leakage. Root cause: same dangling-symlink event dropped the IP boundary rule from context. |

> ⚠️ **This workflow is SPECIFIC to `superpowers-plus` only.** Other superpowers repos are private — commit directly to them as normal.
