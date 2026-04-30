# Push Authorization Gate

Automated — no per-operation approval required. Run the pre-push quality gate before every push and confirm it passes.

## 🔴 Pre-Push Quality Gate (MANDATORY)

Before any `git push`, run `superpowers:pre-push-quality-gate` (battery sentinel valid for HEAD, IP audit clean, lint/typecheck/test pass). Show the actual terminal output in the conversation — claiming "I ran it" without visible output is a violation.

```
Required before push:
  [x] Battery sentinel valid for HEAD  — sentinel SHA matches HEAD
  [x] IP audit output shown            — exit 0 visible
  [x] Quality checks output shown      — exit 0 visible
```

- ❌ **NEVER** push a branch to `dev.azure.com` — branch pushes trigger CI/CD pipelines that auto-deploy
- ❌ **NEVER** frame a deliberate branch gap (staging ahead of main) as a "problem to fix" — the gap is intentional workflow state
- ✅ **ALWAYS** verify `git config user.email` matches the remote's identity before pushing

**For Cari services ([removed-service], [removed-api], etc.), the correct deployment path is:**
```powershell
.\scripts\build-and-push.ps1 -Environment dev [-UpdateECS]
```
This is a HUMAN action. Agents document deployment steps — they do NOT execute them.

| Date | Incident |
|------|----------|
| 2026-03-27 | Agent pushed 4 branches to ADO `[removed-service]`, triggering 2 pipeline runs that progressed through 3/5 stages without human approval. Unsanctioned code deployed to Dev. PRs abandoned/restored, pipeline runs deleted, guardrails created (this section + `push-authorization-gate` skill + `security.md`/`deployment.md` workflow templates). |
| 2026-03-29 | Agent promoted staging → main (95 commits) in `superpowers-plus` without explicit approval. User asked "what's at risk of being left behind?" — agent misframed the staging/main gap as a deficiency, bundled the promotion into a compound question about GitLab mirror + branch cleanup, then executed it after a "yes" that only covered the other actions. Root cause: treating a deliberate workflow state as a problem, and hiding a release decision inside routine housekeeping. |
| 2026-04-30 | Rule changed by user: explicit approval no longer required for commit/push/merge. Quality gates (battery ≥9.2, IP audit, lint) remain mandatory. ADO restriction unchanged. |
