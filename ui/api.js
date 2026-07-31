// API Client - HTTP utility with token management and Authorization header
// Encoding: CP-1252

const API = {
  // Get token from localStorage
  getToken: function() {
    return localStorage.getItem('portal_token');
  },

  // Set token in localStorage
  setToken: function(token) {
    localStorage.setItem('portal_token', token);
  },

  // Remove token from localStorage
  removeToken: function() {
    localStorage.removeItem('portal_token');
  },

  // Check if token exists and is valid
  hasValidToken: function() {
    const token = this.getToken();
    return !!token;
  },

  // Generic fetch wrapper with Authorization header
  fetch: function(url, options = {}) {
    const headers = options.headers || {};
    const token = this.getToken();

    // Add Authorization header if token exists (for non-login requests)
    if (token && !url.includes('/auth/login')) {
      headers['Authorization'] = 'Bearer ' + token;
    }

    // Set default Content-Type if not provided
    if (!headers['Content-Type'] && (options.method === 'POST' || options.method === 'PUT')) {
      headers['Content-Type'] = 'application/json';
    }

    return fetch(url, {
      ...options,
      headers: headers
    });
  },

  // POST /api/auth/login
  login: function(username, password) {
    return this.fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: username, password: password })
    })
      .then(r => {
        if (r.status === 200) {
          return r.json().then(data => {
            // Store token from response
            if (data.token) {
              this.setToken(data.token);
            }
            return data;
          });
        } else if (r.status === 401) {
          return r.json().then(data => {
            throw new Error(data.error || 'Credenciais inv�lidas');
          });
        } else {
          throw new Error('Erro ao autenticar');
        }
      });
  },

  // POST /api/auth/logout
  logout: function() {
    return this.fetch('/api/auth/logout', {
      method: 'POST'
    })
      .then(r => {
        // Always remove token on logout
        this.removeToken();
        return r.json();
      })
      .catch(err => {
        // Even if request fails, remove token
        this.removeToken();
        throw err;
      });
  },

  // POST /api/auth/validate
  validateToken: function() {
    return this.fetch('/api/auth/validate', {
      method: 'POST'
    })
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          // Token expired or invalid
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao validar sess�o');
        }
      });
  },

  // GET /api/portal/extratos
  getExtratos: function(unidade) {
    const url = '/api/portal/extratos' + (unidade ? '?unidade=' + encodeURIComponent(unidade) : '');
    return this.fetch(url)
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar extratos');
        }
      });
  },

  // GET /api/portal/agenda
  getAgenda: function(unidade) {
    const url = '/api/portal/agenda' + (unidade ? '?unidade=' + encodeURIComponent(unidade) : '');
    return this.fetch(url)
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar agenda');
        }
      });
  },

  // GET /api/portal/avisos
  getAvisos: function() {
    return this.fetch('/api/portal/avisos')
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar avisos');
        }
      });
  },

  // GET /api/auditoria/dashboards?periodo=YYYY-MM
  getAuditoriaDashboard: function(periodo) {
    const url = '/api/auditoria/dashboards' + (periodo ? '?periodo=' + encodeURIComponent(periodo) : '');
    return this.fetch(url)
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar dashboard de auditoria');
        }
      });
  },

  // GET /api/auditoria/anomalias?periodo=YYYY-MM&tipo=TIPO
  getAuditoriaAnomalias: function(periodo, tipo) {
    let url = '/api/auditoria/anomalias';
    const params = [];
    if (periodo) params.push('periodo=' + encodeURIComponent(periodo));
    if (tipo) params.push('tipo=' + encodeURIComponent(tipo));
    if (params.length > 0) url += '?' + params.join('&');

    return this.fetch(url)
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar anomalias de auditoria');
        }
      });
  },

  // GET /api/auditoria/alertas
  getAuditoriaAlertas: function() {
    return this.fetch('/api/auditoria/alertas')
      .then(r => {
        if (r.status === 200) {
          return r.json();
        } else if (r.status === 401) {
          this.removeToken();
          throw new Error('Sess�o expirada');
        } else {
          throw new Error('Erro ao carregar alertas de auditoria');
        }
      });
  }
};
