# Portal v3 + Auditoria Dashboard - Frontend Infrastructure

## Overview

This directory contains the Node.js + Express server and SPA infrastructure for the Portal v3 and Auditoria Dashboard.

**Server Port:** 3000
**Backend Proxy:** localhost:8001 (AdvPL Protheus)

## Architecture

```
Browser (http://localhost:3000)
    |
    +-> Express Server (ui/server.js)
        |
        +-> SPA (index.html, assets in ui/public/)
        |
        +-> /api/* Proxy Middleware
            |
            +-> AdvPL Backend (localhost:8001)
```

## Setup

### Prerequisites
- Node.js >= 16.0.0
- npm or yarn

### Installation

```bash
npm install
```

### Running the Server

Development mode (watch disabled):
```bash
npm start
```

Or directly:
```bash
node ui/server.js
```

### Testing

Run server tests:
```bash
npm test
```

Tests verify:
1. Server responds on port 3000
2. SPA root path serves index.html
3. Proxy routes /api/* requests to backend
4. Authorization headers pass through unchanged

## Project Structure

```
ui/
├── server.js              # Express server & proxy configuration
├── index.html             # SPA root (placeholder, Tasks 8-9 will build UI)
├── routes/
│   └── api.js            # API proxy middleware
├── public/               # Static assets (CSS, JS, images)
└── README.md            # This file
```

## API Endpoints

All endpoints are proxied to the AdvPL backend on localhost:8001:

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/validate` - Session validation
- `POST /api/auth/logout` - Logout

### Portal
- `GET /api/portal/extratos` - Account statements
- `GET /api/portal/agenda` - Calendar/schedule
- `GET /api/portal/avisos` - Alerts/notices

### Auditoria
- `GET /api/auditoria/anomalias` - Anomaly audit
- `GET /api/auditoria/dashboards` - Audit dashboards
- `GET /api/auditoria/alertas` - Audit alerts

## Environment

### Encoding
All `.js`/`.ts` files use **CP-1252** encoding (Windows-1252) for Protheus compatibility.

### Browser
- Modern browsers (Chrome, Firefox, Safari, Edge)
- No external CDN dependencies
- All CSS/JS inline or bundled

### Concurrency
Server handles 10+ concurrent connections via Node.js clustering (future enhancement).

## Development Notes

### Adding New Endpoints

1. Backend implements REST endpoint (e.g., POST /api/custom/endpoint)
2. Frontend automatically proxies via `/api/custom/endpoint`
3. No additional configuration needed (catch-all proxy)

### Static Assets

Place static files in `ui/public/`:
- CSS files → `ui/public/css/`
- JavaScript → `ui/public/js/`
- Images → `ui/public/img/`

Server serves these via `express.static()` middleware.

### SPA Routing

All non-API routes (`!== /api/*`) return `index.html`, enabling client-side routing (React, Vue, etc.).

## Troubleshooting

### Backend Connection Error
```
Error: Backend service unavailable
```
→ Ensure AdvPL server is running on localhost:8001

### Port Already in Use
```
Error: listen EADDRINUSE :::3000
```
→ Kill process: `lsof -i :3000` then `kill -9 <PID>`

### Test Failures
```
Server not responding
```
→ Ensure server is running (`npm start`) in another terminal before running tests

## Next Tasks

- **Task 8:** Build Portal v3 UI (React/Vue components)
- **Task 9:** Build Auditoria Dashboard UI
- **Task 10:** Add HTTPS support (optional)

## Notes

- Server written in Node.js + Express for portability
- Lightweight proxy via `http-proxy-middleware`
- No framework-specific dependencies (Vue/React/etc added later)
- Stateless architecture (scalable)
