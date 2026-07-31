// Portal Module - Portal views (extratos, agenda, avisos)
// Encoding: CP-1252

const Portal = {
  // Load all portal data
  loadData: function() {
    const unidade = Auth.getUnidadeFromToken();

    Portal.loadExtratos(unidade);
    Portal.loadAgenda(unidade);
    Portal.loadAvisos();
  },

  // Load extratos (statements)
  loadExtratos: function(unidade) {
    const container = document.getElementById('extratos-container');
    const table = document.getElementById('extratos-table');
    const tbody = table.querySelector('tbody');

    if (!tbody) {
      // Create tbody if not exists
      const tbodyEl = document.createElement('tbody');
      table.appendChild(tbodyEl);
      tbody = tbodyEl;
    }

    // Clear existing rows (keep header)
    while (tbody.firstChild) {
      tbody.removeChild(tbody.firstChild);
    }

    // Show loading message
    if (container) {
      container.querySelector('.error-message')?.remove();
      const loading = container.querySelector('.loading-message');
      if (!loading) {
        const loadingEl = document.createElement('div');
        loadingEl.className = 'loading-message';
        loadingEl.textContent = 'Carregando extratos...';
        container.appendChild(loadingEl);
      }
    }

    API.getExtratos(unidade)
      .then(data => {
        // Remove loading message
        container?.querySelector('.loading-message')?.remove();

        if (!data || data.length === 0) {
          Portal.showNoData('Nenhum extrato disponível', container);
          return;
        }

        // Populate table
        data.forEach(item => {
          const row = tbody.insertRow();
          row.innerHTML = '<td>' + Portal.escapeHtml(item.competencia || '') +
                         '</td><td>' + Portal.formatarValor(item.valor) +
                         '</td><td>' + Portal.formatarData(item.vencimento) +
                         '</td><td><span class="status-badge ' + (item.status === 'pago' ? 'status-ok' : 'status-pending') + '">' +
                         Portal.escapeHtml(item.status || '') + '</span></td>';
        });
      })
      .catch(err => {
        container?.querySelector('.loading-message')?.remove();
        Portal.showError(err.message, container);
      });
  },

  // Load agenda (calendar events)
  loadAgenda: function(unidade) {
    const container = document.getElementById('agenda-container');
    const table = document.getElementById('agenda-table');
    const tbody = table.querySelector('tbody');

    if (!tbody) {
      // Create tbody if not exists
      const tbodyEl = document.createElement('tbody');
      table.appendChild(tbodyEl);
      tbody = tbodyEl;
    }

    // Clear existing rows
    while (tbody.firstChild) {
      tbody.removeChild(tbody.firstChild);
    }

    // Show loading message
    if (container) {
      container.querySelector('.error-message')?.remove();
      const loading = container.querySelector('.loading-message');
      if (!loading) {
        const loadingEl = document.createElement('div');
        loadingEl.className = 'loading-message';
        loadingEl.textContent = 'Carregando agenda...';
        container.appendChild(loadingEl);
      }
    }

    API.getAgenda(unidade)
      .then(data => {
        // Remove loading message
        container?.querySelector('.loading-message')?.remove();

        if (!data || data.length === 0) {
          Portal.showNoData('Nenhum evento na agenda', container);
          return;
        }

        // Populate table
        data.forEach(item => {
          const row = tbody.insertRow();
          row.innerHTML = '<td>' + Portal.escapeHtml(item.competencia || '') +
                         '</td><td>' + Portal.formatarData(item.vencimento) +
                         '</td><td>' + Portal.formatarValor(item.valor) + '</td>';
        });
      })
      .catch(err => {
        container?.querySelector('.loading-message')?.remove();
        Portal.showError(err.message, container);
      });
  },

  // Load avisos (announcements)
  loadAvisos: function() {
    const container = document.getElementById('avisos-container');
    const list = document.getElementById('avisos-list');

    if (!list) return;

    // Clear existing items
    list.innerHTML = '';

    // Show loading message
    if (container) {
      container.querySelector('.error-message')?.remove();
      const loading = container.querySelector('.loading-message');
      if (!loading) {
        const loadingEl = document.createElement('div');
        loadingEl.className = 'loading-message';
        loadingEl.textContent = 'Carregando avisos...';
        container.appendChild(loadingEl);
      }
    }

    API.getAvisos()
      .then(data => {
        // Remove loading message
        container?.querySelector('.loading-message')?.remove();

        if (!data || data.length === 0) {
          Portal.showNoData('Nenhum aviso disponível', container);
          return;
        }

        // Populate list
        data.forEach(item => {
          const itemEl = document.createElement('div');
          itemEl.className = 'aviso-item';
          itemEl.innerHTML = '<h3>' + Portal.escapeHtml(item.titulo || '') + '</h3>' +
                            '<p>' + Portal.escapeHtml(item.corpo || '') + '</p>' +
                            '<small>' + Portal.formatarData(item.data) + '</small>';
          list.appendChild(itemEl);
        });
      })
      .catch(err => {
        container?.querySelector('.loading-message')?.remove();
        Portal.showError(err.message, container);
      });
  },

  // Format currency value
  formatarValor: function(valor) {
    if (!valor && valor !== 0) return '-';
    const num = parseFloat(valor);
    if (isNaN(num)) return '-';
    return 'R$ ' + num.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  },

  // Format date (YYYY-MM-DD to DD/MM/YYYY)
  formatarData: function(data) {
    if (!data) return '-';
    if (typeof data === 'string' && data.length === 10) {
      // YYYY-MM-DD format
      const parts = data.split('-');
      return parts[2] + '/' + parts[1] + '/' + parts[0];
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
  // Portal will be loaded after successful login via Auth.showPortal()
});
