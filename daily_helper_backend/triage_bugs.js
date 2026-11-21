#!/usr/bin/env node
/**
 * Zero-dependency CLI for Closed-Loop In-App Bug Triage.
 * Usage:
 *   node triage_bugs.js list [open|resolved|all]
 *   node triage_bugs.js resolve <uuid> "Fixed in v1.0.1: ..."
 */
const http = require('http');
const https = require('https');

const BASE_URL = (process.env.DAILYHELPER_API_URL || 'http://localhost:8080').replace(/\/$/, '');

function requestJson(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE_URL + path);
    const lib = url.protocol === 'https:' ? https : http;
    const payload = body ? JSON.stringify(body) : null;
    const req = lib.request(
      url,
      {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
        }
      },
      res => {
        let data = '';
        res.on('data', c => (data += c));
        res.on('end', () => {
          try {
            resolve({ statusCode: res.statusCode, body: JSON.parse(data || '{}') });
          } catch (e) {
            reject(new Error(`Invalid JSON (${res.statusCode}): ${data}`));
          }
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function main() {
  const [cmd = 'list', arg1 = 'open', ...rest] = process.argv.slice(2);
  if (cmd === 'list') {
    const status = arg1 || 'open';
    const res = await requestJson('GET', `/api/v1/bugs?status=${encodeURIComponent(status)}&limit=200`);
    const bugs = res.body.bugs || [];
    console.log(`[${status.toUpperCase()}] Total bugs: ${bugs.length}`);
    for (const b of bugs) {
      console.log(`- ${b.id} | ${b.status} | ${b.user_email || b.userEmail} | [${b.page_context || b.pageContext}] ${b.description}`);
    }
    return;
  }

  if (cmd === 'resolve') {
    const id = arg1;
    const notes = rest.join(' ').trim() || 'Resolved';
    if (!id) {
      console.error('Usage: node triage_bugs.js resolve <id> "<resolution notes>"');
      process.exit(1);
    }
    const res = await requestJson('PATCH', `/api/v1/bugs/${encodeURIComponent(id)}`, {
      status: 'resolved',
      resolutionNotes: notes
    });
    console.log(`Resolved ${id}:`, res.body.bug?.status || res.statusCode);
    return;
  }

  console.error('Unknown command. Use "list [open|resolved|all]" or "resolve <id> <notes>"');
  process.exit(1);
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
