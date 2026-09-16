# Perplexity Relay

A single-shot local tool that replaces copy-pasting a Perplexity request/
response through the chat. Ported from the `shipit` project's
`tools/perplexity-relay/` (originally built there) so it's easy to find and
reuse from any project, not tied to one repo's workspace layout.

**Critical invocation rule:** start it with `node server.js` as the *sole*
command in a backgrounded Bash call, nothing after it in the same call.
Wrapping it as `node server.js & sleep 1; some-check` and backgrounding
that whole script instead gets the wrapping job marked "done" once the
follow-up commands finish, killing the still-listening detached server
along with it, usually within a second or two. That causes confusing,
seemingly-random "Submit failed: TypeError: Load failed" reports — the
server itself is fine, the invocation pattern is the bug.

## What it does

1. Claude (or you) writes a drafted request (the paste-block from
   `request-template.md`) to `current-request.txt` in this directory.
2. Run `node server.js` in the background; it opens your default browser to
   `http://127.0.0.1:4317/`.
3. The page shows the request in a read-only box with a **Copy** button.
   Paste it into Perplexity Pro, run it, then paste the response into the
   second box and click **Submit**.
4. The server writes `pending/<timestamp>.json` (request + response +
   submission time), shows a "you can close this tab" confirmation, and
   exits.
5. Claude (or you) picks up the pending file, does independent link/claim
   verification, synthesizes findings into whatever the calling project's
   own notes/prep docs are, and deletes the pending file — it's a transient
   capture, not a second archive. Where the synthesis gets filed is up to
   the calling project's own convention; this tool doesn't impose one.

## Design choices

- **Zero dependencies.** Plain Node `http` module, no `package.json`, no
  build step.
- **Binds to `127.0.0.1` only** — not reachable from the network. No auth,
  same trust boundary as manually copy-pasting today (single local user).
- **Single-shot.** One request per server run; the process exits right
  after a successful submission, or after a 2-hour idle timeout if nothing
  gets submitted, so a forgotten tab doesn't leave it running.
- **The server does not file results anywhere itself.** It only captures
  the raw request/response pair in `pending/`. Verification and synthesis
  still need Claude's (or your) judgment — that's where the real value is,
  not in the copy-paste step.
- `current-request.txt` and `pending/*.json` are gitignored — they're
  per-run working state, not durable history.

## Running it manually (without Claude)

```bash
echo "some request text" > current-request.txt
node server.js
```

Then open `http://127.0.0.1:4317/` if the browser didn't auto-open.

## Request format

See `request-template.md` for the structured request format (objective,
scope, non-goals, questions, required output format, source preservation).
Only the block between the `=== PASTE ===` markers goes into Perplexity —
everything outside it is tracking context for whoever drafted the request.
