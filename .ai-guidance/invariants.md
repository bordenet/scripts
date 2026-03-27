# Invariants — Non-Negotiable Rules

## 🔴 Wiki / Bulk Edit Verification (NON-NEGOTIABLE)

**After EVERY write to any wiki or external document system (Outline, Azure DevOps wiki, Confluence, etc.):**

1. **Re-fetch the page immediately** after the update API call returns.
2. **Verify content integrity:**
   - Full text length is ≥ original text length (minus any intentionally removed content).
   - No truncation — the last section of the page is still present.
   - No `\[` or `\]` escape artifacts introduced.
   - No duplicate TOC blocks or other structural damage.
   - All headings, tables, callout blocks, and embeds that existed before are still present.
3. **If verification fails:** Immediately restore from the original content (which you MUST retain in context until verification passes). Do NOT proceed to the next page.
4. **If you cannot retain the original content in context:** Do NOT update the page. Flag it for manual processing.

**This applies to:**
- Single page edits
- Bulk/batch edits (verify EACH page individually)
- Sub-agent delegated edits (sub-agents MUST verify their own writes)

**Why this exists:** On 2026-03-25, bulk TOC-toggle updates destroyed 5 wiki pages because sub-agents replaced full page content with truncated fragments. The `update_document_outline` API replaces the ENTIRE page text — any truncation is catastrophic and irreversible without manual revision restore.

| Date | Incident |
|------|----------|
| 2026-03-25 | Sub-agents updating UNWRAPPED_TOC pages passed truncated text to update_document_outline, destroying 5 pages (DELTA-1234, Engineer Onboarding, Heroics, Disagree and Commit, Coding Agent: Augment.ai). Root cause: sub-agent context couldn't hold full page text while constructing the update. |

---

## 🔴 Sub-Agent Content Manipulation Safety

When delegating wiki/document edits to sub-agents:

- **Never delegate mid-page text surgery to sub-agents** if the page is large (>5,000 chars). The sub-agent's context may truncate the content.
- **Prefer prepend/append operations** which are less likely to cause truncation.
- For complex mid-page edits on large pages, do the edit yourself in the main agent where you can verify the full text.
- Sub-agents MUST echo the text length before and after their edit. If `after < before` and no content was intentionally removed, the edit is bad.

