// Portal v3 + Auditoria Dashboard - Server & Proxy
// Purpose: Serve SPA on :3000 and proxy /api/* to AdvPL backend on :8001
// Encoding: CP-1252

const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const path = require('path');

const app = express();
const PORT = 3000;
const BACKEND_URL = 'http://localhost:8001';

// Middleware: parse JSON bodies
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Middleware: logging (simple)
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Proxy middleware: /api/* -> backend :8001
// - Pass through Authorization header unchanged
// - Rewrite path to preserve /api prefix
app.use('/api', createProxyMiddleware({
  target: BACKEND_URL,
  changeOrigin: false,
  pathRewrite: {
    '^/api': '/api' // Keep /api prefix
  },
  // Preserve Authorization header
  onProxyReq: (proxyReq, req, res) => {
    if (req.get('Authorization')) {
      proxyReq.setHeader('Authorization', req.get('Authorization'));
    }
  },
  // Log proxy requests
  onProxyRes: (proxyRes, req, res) => {
    console.log(`[PROXY] ${req.method} ${req.path} -> ${proxyRes.statusCode}`);
  },
  // Error handling
  onError: (err, req, res) => {
    console.error(`[PROXY ERROR] ${req.method} ${req.path}:`, err.message);
    res.status(503).json({
      error: 'Backend service unavailable',
      details: err.message
    });
  }
}));

// Static: serve public/ folder
app.use(express.static(path.join(__dirname, 'public')));

// SPA fallback: serve index.html for all non-API routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.get('*', (req, res) => {
  // If not starting with /api, serve index.html (SPA)
  if (!req.path.startsWith('/api')) {
    res.sendFile(path.join(__dirname, 'index.html'));
  } else {
    res.status(404).json({ error: 'Not Found' });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`[SERVER] Listening on http://localhost:${PORT}`);
  console.log(`[PROXY] Proxying /api/* to ${BACKEND_URL}`);
});
