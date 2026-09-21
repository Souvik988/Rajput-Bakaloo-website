// DEV-ONLY combined local test stack for the Flutter Web build:
//   127.0.0.1:8096 — serves build/web (static)
//   127.0.0.1:9443 — CORS proxy to https://api.bakaloo.in
//
// NOT part of the shipped app or the backend — production deployments on
// *.bakaloo.in origins talk to the API directly (its CORS allowlist covers
// them). The proxy also rewrites the Ola Maps styleUrl to itself so the
// MapLibre style document loads same-origin (the backend only emits CORS
// headers for *.bakaloo.in origins, and its styleUrl embeds its own public
// host). Ola's tile/sprite/glyph CDN sends Access-Control-Allow-Origin: *
// and is fetched directly.
//
// Usage: node tool/dev_servers.js
const http = require('http');
const https = require('https');
const fs = require('fs');
const path = require('path');

const UPSTREAM = 'api.bakaloo.in';
const STATIC_PORT = 8096;
const PROXY_PORT = 9443;
const WEB_ROOT = path.join(__dirname, '..', 'build', 'web');
const STYLE_URL_PATH = '/api/v1/maps/ola/style-url';

const MIME = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
};

// ── Static server (build/web) ────────────────────────────────────────────
function startStatic() {
  const server = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]);
    if (p === '/') p = '/index.html';
    const file = path.join(WEB_ROOT, p);
    if (!file.startsWith(WEB_ROOT)) {
      res.writeHead(403);
      res.end();
      return;
    }
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end('not found');
        return;
      }
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
        'Cache-Control': 'no-store',
      });
      res.end(data);
    });
  });
  server.on('error', (err) => {
    console.error('[static] error:', err.message, '— restarting in 2s');
    setTimeout(() => {
      server.close();
      startStatic();
    }, 2000);
  });
  server.listen(STATIC_PORT, '127.0.0.1', () => {
    console.log(`[static] http://127.0.0.1:${STATIC_PORT} -> ${WEB_ROOT}`);
  });
}

// ── CORS proxy (api.bakaloo.in) ──────────────────────────────────────────
function addCors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', req.headers.origin || '*');
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization, X-Requested-With, X-Shop-Id',
  );
  res.setHeader(
    'Access-Control-Allow-Methods',
    'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  );
}

function proxy(req, res, transform) {
  const headers = { ...req.headers, host: UPSTREAM };
  if (transform) headers['accept-encoding'] = 'identity';
  const upstream = https.request(
    {
      hostname: UPSTREAM,
      port: 443,
      path: req.url,
      method: req.method,
      headers,
    },
    (up) => {
      addCors(req, res);
      if (!transform) {
        res.writeHead(up.statusCode, up.headers);
        up.pipe(res);
        return;
      }
      const chunks = [];
      up.on('data', (c) => chunks.push(c));
      up.on('end', () => {
        let body = Buffer.concat(chunks).toString('utf8');
        body = transform(body);
        res.writeHead(up.statusCode, {
          ...up.headers,
          'content-length': Buffer.byteLength(body),
        });
        res.end(body);
      });
    },
  );
  upstream.on('error', (err) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'proxy_upstream_failed', detail: String(err) }));
  });
  req.pipe(upstream);
}

function startProxy() {
  const server = http.createServer((req, res) => {
    if (req.method === 'OPTIONS') {
      addCors(req, res);
      res.writeHead(204);
      res.end();
      return;
    }
    const isStyleUrl = req.url.startsWith(STYLE_URL_PATH);
    proxy(
      req,
      res,
      isStyleUrl
        ? (body) =>
            body.split('https://api.bakaloo.in').join(`http://127.0.0.1:${PROXY_PORT}`)
        : null,
    );
  });

  // WebSocket passthrough (Socket.IO websocket transport)
  server.on('upgrade', (req, socket, head) => {
    const upstream = https.request({
      hostname: UPSTREAM,
      port: 443,
      path: req.url,
      method: 'GET',
      headers: { ...req.headers, host: UPSTREAM },
    });
    upstream.on('upgrade', (upRes, upSocket, upHead) => {
      const lines = ['HTTP/1.1 101 Switching Protocols'];
      for (const [k, v] of Object.entries(upRes.headers)) {
        lines.push(`${k}: ${v}`);
      }
      socket.write(lines.join('\r\n') + '\r\n\r\n');
      if (upHead && upHead.length) socket.write(upHead);
      upSocket.pipe(socket);
      socket.pipe(upSocket);
      socket.on('error', () => {});
      upSocket.on('error', () => {});
    });
    upstream.on('error', () => socket.destroy());
    upstream.end();
  });

  server.on('error', (err) => {
    console.error('[proxy] error:', err.message, '— restarting in 2s');
    setTimeout(() => {
      server.close();
      startProxy();
    }, 2000);
  });
  server.listen(PROXY_PORT, '127.0.0.1', () => {
    console.log(`[proxy] http://127.0.0.1:${PROXY_PORT} -> https://${UPSTREAM}`);
  });
}

startStatic();
startProxy();

// Keep the process alive even if a socket hiccups.
process.on('uncaughtException', (err) => {
  console.error('[uncaught]', err.message);
});
