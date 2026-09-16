#!/usr/bin/env node
// Single-shot local relay: shows Claude's drafted Perplexity request in a
// browser tab, captures the pasted-back response, writes it to pending/,
// then exits. No dependencies, no build step. See README.md in this
// directory for the full flow.

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const HOST = '127.0.0.1';
const PORT = 4317;
const DIR = __dirname;
const REQUEST_FILE = path.join(DIR, 'current-request.txt');
const PENDING_DIR = path.join(DIR, 'pending');
const IDLE_TIMEOUT_MS = 2 * 60 * 60 * 1000; // 2 hours

const PREFILLED_RESPONSE = `Perplexity.ai reply:

\`\`\`

\`\`\`


Instinct.ai reply:

\`\`\`

\`\`\`
`;

function escapeHtml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function readRequestText() {
  if (!fs.existsSync(REQUEST_FILE)) {
    console.error(`Missing ${REQUEST_FILE}. Write the request text there before starting this server.`);
    process.exit(1);
  }
  return fs.readFileSync(REQUEST_FILE, 'utf8');
}

function renderPage(requestText, status) {
  const safeRequest = escapeHtml(requestText);
  const safePrefilledResponse = escapeHtml(PREFILLED_RESPONSE);
  const statusHtml = status
    ? `<p class="status">${escapeHtml(status)}</p>`
    : '';
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Perplexity Relay</title>
<style>
  body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; }
  h2 { margin-top: 2rem; }
  textarea { width: 100%; box-sizing: border-box; font-family: ui-monospace, monospace; font-size: 13px; }
  button { font-size: 14px; padding: 0.5rem 1rem; margin-top: 0.5rem; cursor: pointer; }
  .status { color: #0a7d29; font-weight: bold; }
  .error { color: #b00020; font-weight: bold; }
</style>
</head>
<body>
<h1>Perplexity Relay</h1>
${statusHtml}

<h2>1. Copy this request into Perplexity Pro</h2>
<textarea id="request" rows="16" readonly>${safeRequest}</textarea>
<br>
<button onclick="copyRequest()">Copy request</button>
<span id="copy-confirm"></span>

<h2>2. Paste Perplexity's response here, then submit</h2>
<textarea id="response" rows="16" placeholder="Paste the full response here">${safePrefilledResponse}</textarea>
<br>
<button id="submit-btn" onclick="submitResponse()" disabled>Submit</button>
<span id="submit-status"></span>

<script>
function copyRequest() {
  const text = document.getElementById('request').value;
  navigator.clipboard.writeText(text).then(() => {
    document.getElementById('copy-confirm').textContent = ' Copied.';
    document.getElementById('submit-btn').disabled = false;
  }).catch(err => {
    document.getElementById('copy-confirm').textContent = ' Copy failed, select and copy manually: ' + err;
  });
}

function submitResponse() {
  const responseText = document.getElementById('response').value.trim();
  const statusEl = document.getElementById('submit-status');
  if (!responseText) {
    statusEl.textContent = ' Paste a response first.';
    statusEl.className = 'error';
    return;
  }
  document.getElementById('submit-btn').disabled = true;
  statusEl.textContent = ' Submitting...';
  statusEl.className = '';
  fetch('/submit', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ responseText })
  }).then(r => {
    if (!r.ok) throw new Error('server returned ' + r.status);
    return r.text();
  }).then(() => {
    document.body.innerHTML = '<h1>Received</h1><p>You can close this tab.</p>';
  }).catch(err => {
    statusEl.textContent = ' Submit failed: ' + err + '. The server may have already exited, check your terminal.';
    statusEl.className = 'error';
    document.getElementById('submit-btn').disabled = false;
  });
}
</script>
</body>
</html>`;
}

function openBrowser(url) {
  const platform = process.platform;
  const cmd = platform === 'darwin' ? `open "${url}"`
    : platform === 'win32' ? `start "" "${url}"`
    : `xdg-open "${url}"`;
  exec(cmd, (err) => {
    if (err) {
      console.log(`Could not auto-open a browser (${err.message}). Open this URL manually: ${url}`);
    }
  });
}

const requestText = readRequestText();

const idleTimer = setTimeout(() => {
  console.error('Timed out waiting for a submission after 2 hours, exiting.');
  process.exit(1);
}, IDLE_TIMEOUT_MS);
idleTimer.unref();

const server = http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(renderPage(requestText));
    return;
  }

  if (req.method === 'POST' && req.url === '/submit') {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      let parsed;
      try {
        parsed = JSON.parse(body);
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('Invalid JSON body');
        return;
      }
      const responseText = (parsed.responseText || '').trim();
      if (!responseText) {
        res.writeHead(400, { 'Content-Type': 'text/plain' });
        res.end('responseText is required');
        return;
      }

      fs.mkdirSync(PENDING_DIR, { recursive: true });
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const outFile = path.join(PENDING_DIR, `${timestamp}.json`);
      fs.writeFileSync(outFile, JSON.stringify({
        requestText,
        responseText,
        submittedAt: new Date().toISOString(),
      }, null, 2));

      console.log(`Received submission, wrote ${outFile}`);
      clearTimeout(idleTimer);

      // Tell the client not to keep this connection alive, then wait for
      // Node to confirm the response actually finished writing before
      // exiting. A bare setTimeout()-then-exit truncated in-flight
      // responses in some browsers (observed: Safari fetch() reporting
      // "TypeError: Load failed" even though this file write above had
      // already succeeded) because process.exit() doesn't wait for a
      // keep-alive connection to close cleanly.
      res.writeHead(200, { 'Content-Type': 'text/plain', 'Connection': 'close' });
      res.end('OK');

      let exited = false;
      const exitOnce = () => {
        if (exited) return;
        exited = true;
        process.exit(0);
      };
      res.on('finish', () => {
        server.close(exitOnce);
      });
      setTimeout(exitOnce, 3000); // backstop, shouldn't normally fire
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Check for a stray server process (e.g. lsof -i :${PORT}) and stop it before retrying.`);
    process.exit(1);
  }
  throw err;
});

server.listen(PORT, HOST, () => {
  const url = `http://${HOST}:${PORT}/`;
  console.log(`Perplexity Relay listening on ${url}`);
  openBrowser(url);
});
