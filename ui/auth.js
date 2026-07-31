// Auth Module - Login form handling and session management
// Encoding: CP-1252

const Auth = {
  // Initialize auth UI
  init: function() {
    const form = document.getElementById('login-form');
    const submitBtn = document.getElementById('login-submit');
    const errorMsg = document.getElementById('login-error');

    if (!form) return;

    form.addEventListener('submit', function(e) {
      e.preventDefault();
      Auth.handleLogin();
    });

    // Check if already logged in
    if (API.hasValidToken()) {
      Auth.showPortal();
    } else {
      Auth.showLogin();
    }
  },

  // Handle login form submission
  handleLogin: function() {
    const usernameInput = document.getElementById('login-username');
    const passwordInput = document.getElementById('login-password');
    const submitBtn = document.getElementById('login-submit');
    const errorMsg = document.getElementById('login-error');

    const username = usernameInput.value.trim();
    const password = passwordInput.value.trim();

    if (!username || !password) {
      Auth.showError('Usu�rio e senha s�o obrigat�rios', errorMsg);
      return;
    }

    // Disable submit button during request
    submitBtn.disabled = true;
    submitBtn.textContent = 'Autenticando...';
    errorMsg.textContent = '';

    API.login(username, password)
      .then(data => {
        // Clear form
        usernameInput.value = '';
        passwordInput.value = '';
        errorMsg.textContent = '';

        // Show portal
        Auth.showPortal();
      })
      .catch(err => {
        Auth.showError(err.message, errorMsg);
      })
      .finally(() => {
        submitBtn.disabled = false;
        submitBtn.textContent = 'Entrar';
      });
  },

  // Show login form
  showLogin: function() {
    const loginSection = document.getElementById('login-section');
    const portalSection = document.getElementById('portal-section');

    if (loginSection) loginSection.style.display = 'block';
    if (portalSection) portalSection.style.display = 'none';

    // Focus username input
    setTimeout(() => {
      const usernameInput = document.getElementById('login-username');
      if (usernameInput) usernameInput.focus();
    }, 100);
  },

  // Show portal (after login)
  showPortal: function() {
    const loginSection = document.getElementById('login-section');
    const portalSection = document.getElementById('portal-section');

    if (loginSection) loginSection.style.display = 'none';
    if (portalSection) portalSection.style.display = 'block';

    // Populate username display from token
    const unidade = Auth.getUnidadeFromToken();
    const usernameDisplay = document.getElementById('username-display');
    if (usernameDisplay && unidade) {
      usernameDisplay.textContent = 'Unidade ' + unidade;
    }

    // Load portal data
    if (typeof Portal !== 'undefined') {
      Portal.loadData();
    }
  },

  // Handle logout
  handleLogout: function() {
    if (!confirm('Tem certeza que deseja sair?')) {
      return;
    }

    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
      logoutBtn.disabled = true;
      logoutBtn.textContent = 'Saindo...';
    }

    API.logout()
      .then(() => {
        Auth.showLogin();
      })
      .catch(err => {
        alert('Erro ao sair: ' + err.message);
      })
      .finally(() => {
        if (logoutBtn) {
          logoutBtn.disabled = false;
          logoutBtn.textContent = 'Sair';
        }
      });
  },

  // Show error message
  showError: function(message, element) {
    if (!element) {
      element = document.getElementById('login-error');
    }
    if (element) {
      element.textContent = message;
      element.style.display = 'block';
    }
  },

  // Extract unidade from token (if available)
  getUnidadeFromToken: function() {
    const token = API.getToken();
    if (!token) return null;

    try {
      // JWT format: header.payload.signature
      const parts = token.split('.');
      if (parts.length !== 3) return null;

      // Decode payload
      const payload = atob(parts[1]);
      const data = JSON.parse(payload);

      return data.unidade || null;
    } catch (e) {
      return null;
    }
  }
};

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', Auth.init);
