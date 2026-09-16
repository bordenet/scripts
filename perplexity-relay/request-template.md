# Perplexity Research Request

Fill this out completely in one pass. Batch every related unknown into a
single request; don't ask the human to run several small ones back to
back.

**Only the block between the two `=== PASTE` markers below goes into
Perplexity.** Everything outside that block is Claude/human tracking
context and must not be copied in, an earlier draft of this template
leaked its "Done when" checklist and archive filename into a live request,
and Perplexity dutifully answered them as if they were research questions.

**Delivery:** once filled out, write the paste-block to
`current-request.txt` in this directory and start `server.js` to pop a
browser tab, rather than pasting it in chat — see this directory's
README.md.

**Unblocks (tracking only, do not paste):** The specific decision or task
this will let you move forward on.

=== PASTE EVERYTHING BELOW THIS LINE INTO PERPLEXITY ===

**Objective:** What this research needs to establish, in one sentence.

**Scope:** What's in bounds for this request.

**Non-goals:** What's explicitly out of bounds, so the response doesn't
sprawl into adjacent topics that don't matter for this decision.

**Suggested Perplexity mode/style:** e.g. Pro Search, a specific focus
filter, or "cite primary sources only."

**Questions (3-7, most important first):**

1.
2.
3.

**Required output format:** How the response should be structured, e.g.
"one paragraph per question, bulleted list of options with a
recommendation, table with columns X/Y/Z."

**Source preservation:** Require inline citations or a source list in the
response. Don't accept an answer with no sources for factual claims.

=== PASTE EVERYTHING ABOVE THIS LINE INTO PERPLEXITY ===

**Open questions Claude still needs answered (tracking only, do not
paste):** Anything not covered above that would still leave a gap after
this research comes back.

**Done when (tracking only, do not paste):**

- [ ] All questions above have a direct answer or an explicit "no reliable
      source found."
- [ ] Sources are preserved for every factual claim.
- [ ] The response is filed per whatever the calling project's own
      convention for research notes is.
- [ ] A short synthesis (findings, caveats, next actions) has been written
      into that filed entry.
