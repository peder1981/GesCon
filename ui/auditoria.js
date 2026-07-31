// Auditoria Module - Auditoria dashboard views (anomalies, alerts, dashboard stats)
// Encoding: CP-1252

const Auditoria = {
  // Current filter state
  selectedTipo: null,
  currentPeriodo: null,

  // Initialize current period (YYYY-MM)
  getPeriodo: function() {
    const d = new Date();
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    return year + '-' + month;
  },

  // Load all auditoria data
  loadData: function() {
    Auditoria.currentPeriodo = Auditoria.getPeriodo();
    Auditoria.loadDashboard(Auditoria.currentPeriodo);
    Auditoria.loadAnomalias(Auditoria.currentPeriodo, null);
    Auditoria.loadAlertas();
  },

  // Load dashboard statistics
  loadDashboard: function(periodo) {
    const container = document.getElementById('dashboard-stats-container');
    if (!container) return;

    // Clear existing content
    container.innerHTML = '';

    // Show loading message
    const loadingEl = document.createElement('div');
    loadingEl.className = 'loading-message';
    loadingEl.textContent = 'Carregando dashboard...';
    container.appendChild(loadingEl);

    API.getAuditoriaDashboard(periodo)
      .then(data => {
        // Remove loading message
        container.querySelector('.loading-message')?.remove();

        if (!data) {
          Auditoria.showError('Nenhum dado disponível', container);
          return;
        }

        // Render stat cards
        const statsHTML = Auditoria.renderDashboardCards(data);
        container.innerHTML += statsHTML;
      })
      .catch(err => {
        container.querySelector('.loading-message')?.remove();
        Auditoria.showError(err.message, container);
      });
  },

  // Render dashboard stat cards
  renderDashboardCards: function(data) {
    const cardTypes = [
      { key: 'total', label: 'Total de Anomalias', color: '#007bff' },
      { key: 'desequilibrio', label: 'Desequilibrio', color: '#dc3545' },
      { key: 'lancamento_orfao', label: 'Lancamento Orfao', color: '#fd7e14' },
      { key: 'cobranca_orfao', label: 'Cobranca Orfa', color: '#ffc107' },
      { key: 'rateio_invalido', label: 'Rateio Invalido', color: '#6f42c1' },
      { key: 'timing_anomalia', label: 'Timing Anormal', color: '#20c997' }
    ];

    let html = '<div class="dashboard-cards">';
    cardTypes.forEach(type => {
      const value = data[type.key] || 0;
      html += '<div class="stat-card" style="border-left-color: ' + type.color + '">';
      html += '<div class="stat-label">' + type.label + '</div>';
      html += '<div class="stat-value" style="color: ' + type.color + '">' + value + '</div>';
      html += '</div>';
    });
    html += '</div>';

    return html;
  },

  // Load anomalias (audits with filter)
  loadAnomalias: function(periodo, tipo) {
    const container = document.getElementById('anomalias-container');
    const table = document.getElementById('anomalias-table');

    if (!container || !table) return;

    // Clear existing rows
    const tbody = table.querySelector('tbody') || table.appendChild(document.createElement('tbody'));
    while (tbody.firstChild) {
      tbody.removeChild(tbody.firstChild);
    }

    // Show loading message
    container.querySelector('.error-message')?.remove();
    container.querySelector('.no-data-message')?.remove();
    const loading = container.querySelector('.loading-message');
    if (!loading) {
      const loadingEl = document.createElement('div');
      loadingEl.className = 'loading-message';
      loadingEl.textContent = 'Carregando anomalias...';
      container.appendChild(loadingEl);
    }

    API.getAuditoriaAnomalias(periodo, tipo)
      .then(data => {
        // Remove loading message
        container?.querySelector('.loading-message')?.remove();

        if (!data || data.length === 0) {
          Auditoria.showNoData('Nenhuma anomalia encontrada', container);
          return;
        }

        // Populate table
        data.forEach(item => {
          const row = tbody.insertRow();
          const statusClass = Auditoria.getStatusClass(item.tipo);
          row.innerHTML = '<td>' + Auditoria.escapeHtml(String(item.id || '')) +
                         '</td><td><span class="anomalia-tipo ' + statusClass + '">' + Auditoria.escapeHtml(item.tipo || '') + '</span>' +
                         '</td><td>' + Auditoria.escapeHtml(item.periodo || '') +
                         '</td><td>' + Auditoria.escapeHtml(item.unidade || '') +
                         '</td><td>' + Auditoria.formatarValor(item.valor) +
                         '</td><td><span class="status-badge ' + (item.status === 'resolvido' ? 'status-ok' : 'status-pending') + '">' +
                         Auditoria.escapeHtml(item.status || '') + '</span></td>' +
                         '<td><button class="action-btn" onclick="Auditoria.viewAnomalia(' + item.id + ')">Ver</button></td>';
        });
      })
      .catch(err => {
        container?.querySelector('.loading-message')?.remove();
        Auditoria.showError(err.message, container);
      });
  },

  // Load alertas
  loadAlertas: function() {
    const container = document.getElementById('alertas-container');
    const list = document.getElementById('alertas-list');

    if (!container || !list) return;

    // Clear existing items
    list.innerHTML = '';

    // Show loading message
    container.querySelector('.error-message')?.remove();
    const loading = container.querySelector('.loading-message');
    if (!loading) {
      const loadingEl = document.createElement('div');
      loadingEl.className = 'loading-message';
      loadingEl.textContent = 'Carregando alertas...';
      container.appendChild(loadingEl);
    }

    API.getAuditoriaAlertas()
      .then(data => {
        // Remove loading message
        container?.querySelector('.loading-message')?.remove();

        if (!data || data.length === 0) {
          Auditoria.showNoData('Nenhum alerta disponível', container);
          return;
        }

        // Populate list
        data.forEach(item => {
          const itemEl = document.createElement('div');
          const tipoClass = Auditoria.getAlertaTipoClass(item.tipo);
          itemEl.className = 'alerta-item ' + tipoClass;
          itemEl.innerHTML = '<div class="alerta-header">' +
                            '<span class="alerta-tipo">' + Auditoria.escapeHtml(item.tipo || '') + '</span>' +
                            '<small>' + Auditoria.formatarData(item.criado_em) + '</small>' +
                            '</div>' +
                            '<div class="alerta-message">' + Auditoria.escapeHtml(item.mensagem || '') + '</div>';
          list.appendChild(itemEl);
        });
      })
      .catch(err => {
        container?.querySelector('.loading-message')?.remove();
        Auditoria.showError(err.message, container);
      });
  },

  // Filter anomalias by type
  filterByTipo: function(tipo) {
    Auditoria.selectedTipo = tipo === 'ALL' ? null : tipo;
    Auditoria.loadAnomalias(Auditoria.currentPeriodo, Auditoria.selectedTipo);

    // Update active filter button
    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.classList.remove('active');
    });
    if (tipo !== 'ALL') {
      document.querySelector('[data-filter="' + tipo + '"]')?.classList.add('active');
    } else {
      document.querySelector('[data-filter="ALL"]')?.classList.add('active');
    }
  },

  // View anomalia details (placeholder)
  viewAnomalia: function(id) {
    alert('Detalhes da anomalia #' + id);
  },

  // Get CSS class for anomalia tipo (for styling)
  getStatusClass: function(tipo) {
    const typeClasses = {
      'DESEQUILIBRIO': 'tipo-desequilibrio',
      'LANCAMENTO_ORFAO': 'tipo-lancamento-orfao',
      'COBRANCA_ORFAO': 'tipo-cobranca-orfao',
      'RATEIO_INVALIDO': 'tipo-rateio-invalido',
      'TIMING_ANOMALIA': 'tipo-timing',
      'USUARIO_ANOMALIA': 'tipo-usuario'
    };
    return typeClasses[tipo] || 'tipo-default';
  },

  // Get CSS class for alerta tipo
  getAlertaTipoClass: function(tipo) {
    const tipoMap = {
      'CRITICO': 'alerta-critico',
      'AVISO': 'alerta-aviso',
      'INFO': 'alerta-info'
    };
    return tipoMap[tipo] || 'alerta-info';
  },

  // Format currency value
  formatarValor: function(valor) {
    if (!valor && valor !== 0) return '-';
    const num = parseFloat(valor);
    if (isNaN(num)) return '-';
    return 'R$ ' + num.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  },

  // Format date (YYYY-MM-DD or ISO string to DD/MM/YYYY)
  formatarData: function(data) {
    if (!data) return '-';
    if (typeof data === 'string') {
      // Handle ISO format (YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD)
      const dateOnly = data.split('T')[0];
      if (dateOnly && dateOnly.length === 10) {
        const parts = dateOnly.split('-');
        return parts[2] + '/' + parts[1] + '/' + parts[0];
      }
    }
    return data;
  },

  // Escape HTML to prevent XSS
  escapeHtml: function(text) {
    if (!text) return '';
    const map = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    };
    return text.toString().replace(/[&<>"']/g, m => map[m]);
  },

  // Show error message
  showError: function(message, container) {
    if (!container) return;

    const errorEl = document.createElement('div');
    errorEl.className = 'error-message';
    errorEl.textContent = 'Erro: ' + message;
    container.appendChild(errorEl);
  },

  // Show "no data" message
  showNoData: function(message, container) {
    if (!container) return;

    const noDataEl = document.createElement('div');
    noDataEl.className = 'no-data-message';
    noDataEl.textContent = message;
    container.appendChild(noDataEl);
  }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
  // Auditoria will be loaded after switching to auditoria tab via switchTab()
});
