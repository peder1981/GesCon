// Portal v3 + Auditoria Dashboard - API Proxy Routes
// Purpose: Route configuration and proxy middleware for /api/* endpoints
// Encoding: CP-1252

const { createProxyMiddleware } = require('http-proxy-middleware');

const BACKEND_URL = 'http://localhost:8001';

/**
 * Configure API proxy middleware
 * Maps /api/* requests to AdvPL backend on :8001
 *
 * Endpoints proxied:
 * - POST /api/auth/login           -> backend login
 * - POST /api/auth/validate        -> session validation
 * - POST /api/auth/logout          -> logout
 * - GET  /api/portal/extratos      -> account statements
 * - GET  /api/portal/agenda        -> calendar/schedule
 * - GET  /api/portal/avisos        -> alerts/notices
 * - GET  /api/auditoria/anomalias  -> anomaly audit
 * - GET  /api/auditoria/dashboards -> audit dashboards
 * - GET  /api/auditoria/alertas    -> audit alerts
 */
function createApiProxy() {
  return createProxyMiddleware({
    target: BACKEND_URL,
    changeOrigin: false,

    // Preserve request path (keep /api prefix)
    pathRewrite: {
      '^/api': '/api'
    },

    // Proxy request interceptor: ensure Authorization header passes through
    onProxyReq: (proxyReq, req, res) => {
      // Pass through Authorization header unchanged
      if (req.get('Authorization')) {
        proxyReq.setHeader('Authorization', req.get('Authorization'));
      }

      // Pass through Content-Type for POST/PUT requests
      if (req.get('Content-Type')) {
        proxyReq.setHeader('Content-Type', req.get('Content-Type'));
      }
    },

    // Proxy response interceptor: logging
    onProxyRes: (proxyRes, req, res) => {
      console.log(
        `[API] ${req.method.toUpperCase().padEnd(6)} ${req.path} -> ${proxyRes.statusCode}`
      );
    },

    // Error handler: backend unavailable or timeout
    onError: (err, req, res) => {
      console.error(
        `[API ERROR] ${req.method} ${req.path} - ${err.code || err.message}`
      );
      res.status(503).json({
        error: 'Backend service unavailable',
        message: err.message,
        path: req.path
      });
    }
  });
}

/**
 * Get proxy configuration
 * Can be mounted on app with: app.use('/api', createApiProxy())
 */
module.exports = {
  createApiProxy,
  BACKEND_URL
};
