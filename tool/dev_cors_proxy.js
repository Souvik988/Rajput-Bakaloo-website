// DEV-ONLY local CORS proxy for verifying the Flutter Web build against the
// production API from a localhost origin. NOT part of the shipped app and
// NOT part of the backend — production deployments on *.bakaloo.in origins
// talk to the API directly (its allowlist covers them).
//
// Usage: node tool/dev_cors_proxy.js  (listens on 127.0.0.1:9443)
const http = require('http');
const https = require('https');

const UPSTREAM = 'api.bakaloo.in';
const PORT = 9443;

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

const server = http.createServer((req, res) => {
  const options = {
    hostname: UPSTREAM,
    port: 443,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: UPSTREAM },
  };
  if (req.method === 'OPTIONS') {
    addCors(req, res);
    res.writeHead(204);
    res.end();
    return;
  }
  const upstream = https.request(options, (up) => {
    addCors(req, res);
    res.writeHead(up.statusCode, up.headers);
    up.pipe(res);
  });
  upstream.on('error', (err) => {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'proxy_upstream_failed', detail: String(err) }));
  });
  req.pipe(upstream);
});

// WebSocket passthrough (Socket.IO websocket transport)
server.on('upgrade', (req, socket, head) => {
  const upstream = https.request(
    {
      hostname: UPSTREAM,
      port: 443,
      path: req.url,
      method: 'GET',
      headers: { ...req.headers, host: UPSTREAM },
    },
  );
  upstream.on('upgrade', (upRes, upSocket, upHead) => {
    const lines = [`HTTP/1.1 101 Switching Protocols`];
    for (const [k, v] of Object.entries(upRes.headers)) {
      lines.push(`${k}: ${v}`);
    }
    socket.write(lines.join('\r\n') + '\r\n\r\n');
    if (upHead && upHead.length) socket.write(upHead);
    upSocket.pipe(socket);
    socket.pipe(upSocket);
  });
  upstream.on('error', () => socket.destroy());
  upstream.end();
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`dev CORS proxy on http://127.0.0.1:${PORT} -> https://${UPSTREAM}`);
});
