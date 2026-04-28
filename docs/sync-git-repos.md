# sync-git-repos.sh

Parallel git sync across multiple repositories. Thin bash wrapper that builds a Go binary on demand, then execs it.

## How It Works

1. Hashes all Go source files (`cmd/`, `internal/`, `go.mod`) — rebuilds the binary only when source changes
2. Pre-warms SSH ControlMaster before spawning goroutines to avoid a connection storm
3. Execs the `gitsync` binary, which runs each repo in a bounded goroutine pool

**Performance:** ~1–3s for 10 repos (was ~90s sequential with the old bash implementation).

## Requirements

- Go (build-time only): `brew install go`
- `flock` (optional, prevents concurrent invocations): `brew install util-linux`

## Usage

```bash
# Sync all repos in ~/git (non-interactively)
./sync-git-repos.sh --all ~/git

# Dry run — show what would happen, make no changes
./sync-git-repos.sh --all --what-if ~/git

# Sync current directory, search subdirectories recursively
./sync-git-repos.sh --all --recursive .
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--all` | Process all repos non-interactively | — |
| `--recursive` | Search all subdirectories | off |
| `--what-if` | Dry run — describe actions, make no changes | off |
| `--no-rebase` | Skip diverged branches instead of rebasing | off |
| `--no-stash` | Skip repos with local changes instead of stashing | off |
| `--force-rebase` | Rebase pushed branches (solo use only; warns to force-push) | off |
| `--verbose` | Show per-repo branch and timing detail | off |
| `--concurrency N` | Max parallel repos | min(CPU, 8) |
| `--fetch-timeout N` | Per-repo fetch timeout in seconds | 30 |
| `--rebase-timeout N` | Per-repo rebase timeout in seconds | 120 |
| `--dir PATH` | Target directory | `.` |

## Output

**Default (compact mode)** — a single rolling progress line updates in-place while syncing. Only repos that need attention are printed:

```
⟳  my-feature-branch                             [12/20]  00:08

Summary (14s)
✓ 18 synced, 1 already current
⊘ Skipped (1):
  • dirty-repo
⚠ Force-push needed:
  git push --force-with-lease origin my-feature  # in feature-repo
```

**`--verbose` mode** — per-repo result lines printed as each completes, plus the full summary breakdown:

```
  ✓  my-app                   (updated main, 1.2s [main])
  ✓  api-service              (up to date)
  ⚠  feature-repo            (rebased — force-push needed: git push --force-with-lease origin my-feature)
  ⊘  dirty-repo              (local changes present and --no-stash set)

Summary (14s)
✓ Updated (1): my-app
• Up to date (1): api-service
⊘ Skipped (1): dirty-repo
```

## Per-Repo Decision Logic

For each repo the binary:

1. Checks for in-progress rebase or merge (skips if found)
2. Detects the parent branch (e.g. `main`, `dev`) via `git log --first-parent`
3. Stashes local changes (unless `--no-stash`)
4. Fetches the parent branch
5. Decides: fast-forward, rebase, or skip (based on divergence and flags)
6. Executes the sync, then pops the stash

## See Also

- Source: [`cmd/gitsync/`](../cmd/gitsync/), [`internal/`](../internal/)
- [git-fetch(1)](https://git-scm.com/docs/git-fetch)
- [git-rebase(1)](https://git-scm.com/docs/git-rebase)
