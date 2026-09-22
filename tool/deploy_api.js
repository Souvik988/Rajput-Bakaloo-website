// Deploys build/web-production to Vercel via the REST API (v13), bypassing
// the CLI. Motivation: the CLI's OIDC handshake hits vercel.com, whose
// freshly-rotated TLS certificate fails "not yet valid" when the machine
// clock is behind — api.vercel.com's long-lived certificate still validates.
// The manifest/uploads dedupe by content SHA, so unchanged files are not
// re-uploaded across deploys.
//
// Usage: node tool/deploy_api.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..', 'build', 'web-production');
const auth = require(path.join(process.env.APPDATA || '', 'com.vercel.cli', 'Data', 'auth.json'));
const API = 'https://api.vercel.com';
const TEAM_ID = 'team_vFoVriCgyqUZ4vHdsSnmr2aF';
const PROJECT = 'rajput-bakaloo-website';

function walk(dir, base) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.vercel') continue;
    const full = path.join(dir, entry.name);
    const rel = base ? base + '/' + entry.name : entry.name;
    if (entry.isDirectory()) {
      out.push(...walk(full, rel));
    } else {
      const buf = fs.readFileSync(full);
      out.push({
        file: rel,
        size: buf.length,
        sha: crypto.createHash('sha1').update(buf).digest('hex'),
        buf,
      });
    }
  }
  return out;
}

async function api(pathname, options) {
  const res = await fetch(API + pathname, {
    ...options,
    headers: {
      Authorization: `Bearer ${auth.token}`,
      ...(options && options.headers),
    },
  });
  const text = await res.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

async function main() {
  const files = walk(ROOT, '');
  console.log(`manifest: ${files.length} files`);
  const manifest = files.map(({ file, size, sha }) => ({ file, size, sha }));
  const bySha = new Map(files.map((f) => [f.sha, f]));

  const payload = {
    name: PROJECT,
    target: 'production',
    files: manifest,
  };

  let res = await api(
    `/v13/deployments?skipAutoDetectionConfirmation=1&teamId=${TEAM_ID}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    },
  );

  let missing =
    (res.body && res.body.error && Array.isArray(res.body.error.missing)
      ? res.body.error.missing.map((m) => (typeof m === 'string' ? { sha: m } : m))
      : (res.body && res.body.missing) || []);
  if (res.status >= 400 && missing.length === 0) {
    console.error('deployment creation failed:', JSON.stringify(res.body).slice(0, 800));
    process.exitCode = 1;
    return;
  }

  let uploaded = 0;
  while (missing.length > 0) {
    console.log(`uploading ${missing.length} missing file(s)...`);
    for (const m of missing) {
      const f = bySha.get(m.sha);
      if (!f) {
        console.error('server requested unknown sha', m.sha);
        process.exit(1);
      }
      const up = await api(
        `/v2/files?teamId=${TEAM_ID}`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': String(f.buf.length),
            'x-now-digest': f.sha,
            'x-now-size': String(f.buf.length),
          },
          body: f.buf,
        },
      );
      if (up.status >= 400) {
        console.error(`upload failed for ${f.file}:`, JSON.stringify(up.body).slice(0, 400));
        process.exitCode = 1;
        return;
      }
      uploaded++;
    }
    res = await api(
      `/v13/deployments?skipAutoDetectionConfirmation=1&teamId=${TEAM_ID}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      },
    );
    missing =
      (res.body && res.body.error && Array.isArray(res.body.error.missing)
        ? res.body.error.missing.map((m) => (typeof m === 'string' ? { sha: m } : m))
        : (res.body && res.body.missing) || []);
    if (res.status >= 400 && missing.length === 0) {
      console.error('deployment creation failed:', JSON.stringify(res.body).slice(0, 800));
      process.exitCode = 1;
      return;
    }
  }
  console.log(`uploaded ${uploaded} new file(s); deployment ${res.body.id} is building`);

  const id = res.body.id;
  for (let i = 0; i < 60; i++) {
    await new Promise((r) => setTimeout(r, 5000));
    const st = await api(`/v13/deployments/${id}?teamId=${TEAM_ID}`);
    const d = st.body;
    process.stdout.write(`[${i}] ${d.readyState} / ${d.status || ''}\r`);
    if (d.readyState === 'READY') {
      console.log(`\nREADY: ${d.url}`);
      console.log(`aliases: ${(d.alias || []).join(', ')}`);
      return;
    }
    if (d.readyState === 'ERROR' || d.readyState === 'CANCELED') {
      console.error(`\ndeployment ${d.readyState}:`, JSON.stringify(d).slice(0, 800));
      process.exit(1);
    }
  }
  console.error('\ntimed out waiting for deployment');
  process.exit(1);
}

main().catch((e) => {
  console.error('fatal:', e && e.cause ? `${e.message} (${e.cause.code || e.cause.message})` : e);
  process.exit(1);
});
