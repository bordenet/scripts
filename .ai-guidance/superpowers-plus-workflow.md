# superpowers-plus: GitHub-First, Then Sync to GitLab (NON-NEGOTIABLE)

`superpowers-plus` has two remotes:

| Remote | URL | Role |
|--------|-----|------|
| `upstream` | `https://github.com/bordenet/superpowers-plus.git` | **Source of truth** — changes land here FIRST via branch → PR → merge |
| `origin` | `https://gitlab.int.callbox.net/mbordenet/superpowers-plus.git` | **Internal fork** — ALWAYS synced from `upstream` after merge |

**Two-step flow (both steps mandatory):**

**Step 1 — GitHub (upstream):** Branch → push to `upstream` → PR on GitHub → merge to `upstream/main`.

**Step 2 — GitLab (origin) sync:** Pull merged changes from `upstream/main` → push to `origin/main` to keep the internal fork synchronized.

- ❌ **NEVER** push changes to `origin` (GitLab) first — GitHub is always first
- ❌ **NEVER** commit directly to `upstream/main` or `origin/main` — always use a branch + PR
- ❌ **NEVER** skip the GitLab sync — both remotes must stay in sync
- ✅ **ALWAYS** branch from `upstream/main` → push to `upstream` → PR on GitHub → merge
- ✅ **ALWAYS** after merge, pull `upstream/main` and push to `origin/main`

```bash
# Step 1: GitHub PR flow
git fetch upstream
git checkout -b fix/my-change upstream/main
# ... make changes, commit ...
git push upstream fix/my-change
# Create PR on GitHub, get it merged.

# Step 2: Sync GitLab fork
git checkout main
git pull upstream main
git push origin main
```

| Date | Incident |
|------|----------|
| 2026-03-24 | Agent edited `doctor-checks.sh` on `origin/main` (GitLab) directly instead of going through GitHub PR. Had to discard local edits; upstream already had the fix. |
| 2026-03-25 | Agent pushed multi-agent claim feature to `origin/main` (GitLab) first, then tried to push to GitHub after. Violated GitHub-only policy despite it being documented. |
| 2026-03-25 | Policy corrected: GitLab sync is now a mandatory second step after every GitHub merge, not a manual Matt-only action. |
| 2026-03-25 | Bulk wiki TOC update destroyed 5 Outline pages. Sub-agents passed truncated text to update API. New invariant: VERIFY EVERY WRITE by re-fetching immediately after update. See `.ai-guidance/invariants.md`. |

> ⚠️ **This workflow is SPECIFIC to `superpowers-plus` only.** Other superpowers repos (`superpowers-callbox`, `superpowers-cari`) are private CallBox repos — commit directly to them as normal.
