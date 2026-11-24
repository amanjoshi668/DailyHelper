#!/usr/bin/env node
/**
 * App-agnostic keyless Google Play Console uploader (Android Publisher API v3).
 * Zero npm dependencies — uses built-in Node.js crypto + fetch.
 *
 * Auth priority:
 *   1. PLAY_ACCESS_TOKEN (pre-minted androidpublisher OAuth token)
 *   2. GCLOUD_USER_TOKEN (mints exact-scope androidpublisher token via IAM Credentials generateAccessToken)
 *   3. Service Account JSON key (--key / PLAY_SERVICE_ACCOUNT_JSON / PLAY_SERVICE_ACCOUNT_JSON_CONTENT)
 */

import crypto from 'node:crypto';
import fs from 'node:fs';

const DEFAULT_SERVICE_ACCOUNT = 'play-release-bot@bullet-journal-514307.iam.gserviceaccount.com';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const IAM_CREDS_BASE = 'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const UPLOAD_BASE = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3';

function parseArgs(argv) {
  const args = {
    packageName: '',
    serviceAccount: process.env.PLAY_SERVICE_ACCOUNT_EMAIL || DEFAULT_SERVICE_ACCOUNT,
    track: 'internal',
    status: 'completed',
    notes: '',
    keyPath: process.env.PLAY_SERVICE_ACCOUNT_JSON || '',
    aab: '',
    mapping: '',
    symbols: '',
    dryRun: false,
    checkAuth: false,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--package') args.packageName = argv[++i];
    else if (a === '--service-account') args.serviceAccount = argv[++i];
    else if (a === '--track') args.track = argv[++i];
    else if (a === '--status') args.status = argv[++i];
    else if (a === '--notes') args.notes = argv[++i];
    else if (a === '--key') args.keyPath = argv[++i];
    else if (a === '--aab') args.aab = argv[++i];
    else if (a === '--mapping') args.mapping = argv[++i];
    else if (a === '--symbols') args.symbols = argv[++i];
    else if (a === '--dry-run') args.dryRun = true;
    else if (a === '--check-auth') args.checkAuth = true;
    else if (a === '--help' || a === '-h') {
      console.log(`Usage: node upload_to_play.mjs --package <applicationId> --aab <file.aab> [--mapping <mapping.txt>] [--symbols <symbols.zip>] [--track internal|alpha|beta|production] [--status completed|draft] [--notes "What's new"] [--service-account <sa@proj.iam.gserviceaccount.com>] [--key <sa.json>] [--dry-run] [--check-auth]`);
      process.exit(0);
    }
  }
  return args;
}

function base64url(input) {
  return Buffer.from(input).toString('base64url');
}

async function getAccessTokenFromJson(sa) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: SCOPE,
    aud: TOKEN_URL,
    exp: now + 3600,
    iat: now,
  }));
  const unsigned = `${header}.${claim}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  const signature = signer.sign(sa.private_key).toString('base64url');

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error(`OAuth token exchange failed (${res.status}): ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

async function mintImpersonatedToken(userToken, serviceAccountEmail) {
  const res = await fetch(`${IAM_CREDS_BASE}/${serviceAccountEmail}:generateAccessToken`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${userToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ scope: [SCOPE] }),
  });
  const data = await res.json();
  if (!res.ok || !data.accessToken) {
    throw new Error(`IAM generateAccessToken failed (${res.status}): ${JSON.stringify(data)}`);
  }
  return data.accessToken;
}

async function apiJson(url, method, token, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let parsed;
  try { parsed = text ? JSON.parse(text) : {}; } catch { parsed = { raw: text }; }
  if (!res.ok) {
    throw new Error(`Google Play API ${method} ${url} failed (${res.status}): ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function uploadMedia(url, token, filePath, contentType) {
  const bytes = fs.readFileSync(filePath);
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': contentType,
      'Content-Length': String(bytes.length),
    },
    body: bytes,
  });
  const text = await res.text();
  let parsed;
  try { parsed = text ? JSON.parse(text) : {}; } catch { parsed = { raw: text }; }
  if (!res.ok) {
    throw new Error(`Google Play upload ${url} failed (${res.status}): ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.packageName) {
    console.error('❌ Missing required --package <applicationId>');
    process.exit(1);
  }

  let token = (process.env.PLAY_ACCESS_TOKEN || '').trim();
  const userToken = (process.env.GCLOUD_USER_TOKEN || '').trim();
  if (token) {
    console.log('🔐 Using keyless PLAY_ACCESS_TOKEN.');
  } else if (userToken) {
    console.log(`🔐 Minting keyless androidpublisher token via ${args.serviceAccount}...`);
    token = await mintImpersonatedToken(userToken, args.serviceAccount);
    console.log('✅ Authenticated keylessly.');
  } else if (process.env.PLAY_SERVICE_ACCOUNT_JSON_CONTENT) {
    const sa = JSON.parse(process.env.PLAY_SERVICE_ACCOUNT_JSON_CONTENT);
    token = await getAccessTokenFromJson(sa);
    console.log(`✅ Authenticated as ${sa.client_email}.`);
  } else if (args.keyPath && fs.existsSync(args.keyPath)) {
    const sa = JSON.parse(fs.readFileSync(args.keyPath, 'utf8'));
    token = await getAccessTokenFromJson(sa);
    console.log(`✅ Authenticated as ${sa.client_email}.`);
  } else {
    console.error('❌ No credentials found. Pass GCLOUD_USER_TOKEN="$(gcloud auth print-access-token)" (recommended keyless) or --key <sa.json>.');
    process.exit(2);
  }

  if (args.checkAuth) {
    const edit = await apiJson(`${API_BASE}/applications/${args.packageName}/edits`, 'POST', token, {});
    const tracks = await apiJson(`${API_BASE}/applications/${args.packageName}/edits/${edit.id}/tracks`, 'GET', token);
    await fetch(`${API_BASE}/applications/${args.packageName}/edits/${edit.id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    console.log(`✅ Verified write access to ${args.packageName}! Tracks: ${(tracks.tracks || []).map((t) => t.track).join(', ')}`);
    return;
  }

  if (!args.aab || !fs.existsSync(args.aab)) {
    console.error(`❌ AAB file not found: ${args.aab || '(missing --aab)'}`);
    process.exit(1);
  }

  console.log(`📦 Package: ${args.packageName}`);
  console.log(`🎯 Track:   ${args.track} (status: ${args.status})`);
  console.log(`📄 AAB:     ${args.aab}`);
  if (args.mapping) console.log(`🗺️  Mapping: ${args.mapping}`);
  if (args.symbols) console.log(`🧩 Symbols: ${args.symbols}`);

  if (args.dryRun) {
    console.log('🧪 Dry-run mode: skipping upload.');
    return;
  }

  const edit = await apiJson(`${API_BASE}/applications/${args.packageName}/edits`, 'POST', token, {});
  const editId = edit.id;
  console.log(`📝 Created Play edit: ${editId}`);

  console.log('⬆️  Uploading App Bundle...');
  const bundle = await uploadMedia(
    `${UPLOAD_BASE}/applications/${args.packageName}/edits/${editId}/bundles?uploadType=media`,
    token,
    args.aab,
    'application/octet-stream',
  );
  const versionCode = bundle.versionCode;
  console.log(`✅ Uploaded bundle versionCode=${versionCode} (sha256=${bundle.sha256})`);

  if (args.mapping && fs.existsSync(args.mapping)) {
    console.log('⬆️  Uploading ProGuard/R8 mapping.txt...');
    await uploadMedia(
      `${UPLOAD_BASE}/applications/${args.packageName}/edits/${editId}/apks/${versionCode}/deobfuscationFiles/proguard?uploadType=media`,
      token,
      args.mapping,
      'application/octet-stream',
    );
    console.log(`✅ Uploaded mapping.txt for versionCode=${versionCode}`);
  }

  if (args.symbols && fs.existsSync(args.symbols)) {
    console.log('⬆️  Uploading native debug symbols zip...');
    await uploadMedia(
      `${UPLOAD_BASE}/applications/${args.packageName}/edits/${editId}/apks/${versionCode}/deobfuscationFiles/nativeCode?uploadType=media`,
      token,
      args.symbols,
      'application/octet-stream',
    );
    console.log(`✅ Uploaded native-debug-symbols.zip for versionCode=${versionCode}`);
  }

  const release = { versionCodes: [String(versionCode)], status: args.status };
  if (args.notes && args.notes.trim().length > 0) {
    release.releaseNotes = [{ language: 'en-US', text: args.notes.trim() }];
  }
  await apiJson(
    `${API_BASE}/applications/${args.packageName}/edits/${editId}/tracks/${args.track}`,
    'PUT',
    token,
    { track: args.track, releases: [release] },
  );
  console.log(`✅ Assigned versionCode=${versionCode} to track '${args.track}' (${args.status})`);

  await apiJson(`${API_BASE}/applications/${args.packageName}/edits/${editId}:commit`, 'POST', token, {});
  console.log(`🚀 Released versionCode=${versionCode} to Google Play '${args.track}' track!`);
}

main().catch((err) => {
  console.error(`\n❌ Release upload failed:\n${err.message}\n`);
  process.exit(1);
});
