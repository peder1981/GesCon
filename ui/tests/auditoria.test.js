// Auditoria Dashboard Tests
// Encoding: CP-1252
// Run with: node tests/auditoria.test.js or in browser console

const assert = (condition, message) => {
  if (!condition) {
    throw new Error('Assertion failed: ' + message);
  }
  console.log('[OK] ' + message);
};

const assertEquals = (actual, expected, message) => {
  if (actual !== expected) {
    throw new Error('Assertion failed: ' + message + ' (expected: ' + expected + ', got: ' + actual + ')');
  }
  console.log('[OK] ' + message);
};

const assertArrayLength = (arr, len, message) => {
  if (!Array.isArray(arr) || arr.length !== len) {
    throw new Error('Assertion failed: ' + message + ' (expected length: ' + len + ', got: ' + (arr ? arr.length : 'not an array') + ')');
  }
  console.log('[OK] ' + message);
};

// Test 1: Dashboard data loading
function testDashboardLoad() {
  console.log('\n--- Test 1: Dashboard Load ---');

  const mockData = {
    total: 42,
    desequilibrio: 10,
    lancamento_orfao: 8,
    cobranca_orfao: 5,
    rateio_invalido: 12,
    timing_anomalia: 7,
    usuario_anomalia: 0
  };

  // Test rendering cards
  const html = Auditoria.renderDashboardCards(mockData);
  assert(html.includes('42'), 'Total should be 42');
  assert(html.includes('10'), 'Desequilibrio should be 10');
  assert(html.includes('8'), 'Lancamento orfao should be 8');
  assert(html.includes('5'), 'Cobranca orfao should be 5');
  assert(html.includes('12'), 'Rateio invalido should be 12');
  assert(html.includes('7'), 'Timing anomalia should be 7');
  assert(html.includes('stat-card'), 'Should render stat cards');
  console.log('Dashboard rendering: PASS');
}

// Test 2: Period calculation
function testPeriodoCalculation() {
  console.log('\n--- Test 2: Periodo Calculation ---');

  const periodo = Auditoria.getPeriodo();
  assert(periodo.match(/^\d{4}-\d{2}$/), 'Period should be YYYY-MM format');
  console.log('Current period: ' + periodo);
  console.log('Period format: PASS');
}

// Test 3: Anomalia type status class
function testAnomaliaTipoClass() {
  console.log('\n--- Test 3: Anomalia Type Classes ---');

  assertEquals(Auditoria.getStatusClass('DESEQUILIBRIO'), 'tipo-desequilibrio', 'DESEQUILIBRIO should map to tipo-desequilibrio');
  assertEquals(Auditoria.getStatusClass('LANCAMENTO_ORFAO'), 'tipo-lancamento-orfao', 'LANCAMENTO_ORFAO should map to tipo-lancamento-orfao');
  assertEquals(Auditoria.getStatusClass('COBRANCA_ORFAO'), 'tipo-cobranca-orfao', 'COBRANCA_ORFAO should map to tipo-cobranca-orfao');
  assertEquals(Auditoria.getStatusClass('RATEIO_INVALIDO'), 'tipo-rateio-invalido', 'RATEIO_INVALIDO should map to tipo-rateio-invalido');
  assertEquals(Auditoria.getStatusClass('TIMING_ANOMALIA'), 'tipo-timing', 'TIMING_ANOMALIA should map to tipo-timing');
  assertEquals(Auditoria.getStatusClass('USUARIO_ANOMALIA'), 'tipo-usuario', 'USUARIO_ANOMALIA should map to tipo-usuario');
  assertEquals(Auditoria.getStatusClass('UNKNOWN'), 'tipo-default', 'Unknown type should map to tipo-default');
  console.log('Anomalia type classes: PASS');
}

// Test 4: Alerta type class
function testAlertaTipoClass() {
  console.log('\n--- Test 4: Alerta Type Classes ---');

  assertEquals(Auditoria.getAlertaTipoClass('CRITICO'), 'alerta-critico', 'CRITICO should map to alerta-critico');
  assertEquals(Auditoria.getAlertaTipoClass('AVISO'), 'alerta-aviso', 'AVISO should map to alerta-aviso');
  assertEquals(Auditoria.getAlertaTipoClass('INFO'), 'alerta-info', 'INFO should map to alerta-info');
  assertEquals(Auditoria.getAlertaTipoClass('UNKNOWN'), 'alerta-info', 'Unknown type should default to alerta-info');
  console.log('Alerta type classes: PASS');
}

// Test 5: Value formatting
function testFormatarValor() {
  console.log('\n--- Test 5: Value Formatting ---');

  assertEquals(Auditoria.formatarValor(1234.56), 'R$ 1.234,56', 'Should format value with comma decimal and dot thousand separator');
  assertEquals(Auditoria.formatarValor(1000000), 'R$ 1.000.000,00', 'Should handle large values');
  assertEquals(Auditoria.formatarValor(0), 'R$ 0,00', 'Should handle zero');
  assertEquals(Auditoria.formatarValor(null), '-', 'Should return dash for null');
  assertEquals(Auditoria.formatarValor(undefined), '-', 'Should return dash for undefined');
  console.log('Value formatting: PASS');
}

// Test 6: Date formatting
function testFormatarData() {
  console.log('\n--- Test 6: Date Formatting ---');

  assertEquals(Auditoria.formatarData('2025-07-30'), '30/07/2025', 'Should format YYYY-MM-DD to DD/MM/YYYY');
  assertEquals(Auditoria.formatarData('2025-07-30T14:30:00'), '30/07/2025', 'Should handle ISO datetime format');
  assertEquals(Auditoria.formatarData(null), '-', 'Should return dash for null');
  assertEquals(Auditoria.formatarData(''), '-', 'Should return dash for empty string');
  console.log('Date formatting: PASS');
}

// Test 7: HTML escaping
function testEscapeHtml() {
  console.log('\n--- Test 7: HTML Escaping ---');

  assertEquals(Auditoria.escapeHtml('<script>alert("xss")</script>'), '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;', 'Should escape script tags');
  assertEquals(Auditoria.escapeHtml('foo & bar'), 'foo &amp; bar', 'Should escape ampersands');
  assertEquals(Auditoria.escapeHtml('foo "bar"'), 'foo &quot;bar&quot;', 'Should escape quotes');
  assertEquals(Auditoria.escapeHtml("foo 'bar'"), "foo &#039;bar&#039;", 'Should escape single quotes');
  assertEquals(Auditoria.escapeHtml(null), '', 'Should return empty string for null');
  console.log('HTML escaping: PASS');
}

// Test 8: Filter state management
function testFilterStateManagement() {
  console.log('\n--- Test 8: Filter State Management ---');

  // Initial state
  assertEquals(Auditoria.selectedTipo, null, 'Initial filter should be null');

  // Simulate filter change (without DOM manipulation)
  Auditoria.selectedTipo = 'DESEQUILIBRIO';
  assertEquals(Auditoria.selectedTipo, 'DESEQUILIBRIO', 'Filter should update to DESEQUILIBRIO');

  Auditoria.selectedTipo = null;
  assertEquals(Auditoria.selectedTipo, null, 'Filter should reset to null');

  console.log('Filter state management: PASS');
}

// Test 9: Mock API responses structure
function testApiResponseStructure() {
  console.log('\n--- Test 9: API Response Structures ---');

  // Test dashboard response structure
  const dashboardData = {
    total: 42,
    desequilibrio: 10,
    lancamento_orfao: 8,
    cobranca_orfao: 5,
    rateio_invalido: 12,
    timing_anomalia: 7,
    usuario_anomalia: 0
  };

  assert(dashboardData.total !== undefined, 'Dashboard should have total field');
  assert(dashboardData.desequilibrio !== undefined, 'Dashboard should have desequilibrio field');
  assert(dashboardData.lancamento_orfao !== undefined, 'Dashboard should have lancamento_orfao field');

  // Test anomalia response structure
  const anomaliaData = {
    id: 1,
    tipo: 'DESEQUILIBRIO',
    periodo: '2025-07',
    unidade: 'T01',
    valor: 1234.56,
    descricao: 'Desequilibrio de caixa',
    criado_em: '2025-07-30',
    status: 'pendente'
  };

  assert(anomaliaData.id !== undefined, 'Anomalia should have id');
  assert(anomaliaData.tipo !== undefined, 'Anomalia should have tipo');
  assert(anomaliaData.valor !== undefined, 'Anomalia should have valor');
  assert(anomaliaData.status !== undefined, 'Anomalia should have status');

  // Test alerta response structure
  const alertaData = {
    id: 1,
    tipo: 'CRITICO',
    mensagem: 'Anomalia detectada em T01',
    criado_em: '2025-07-30T14:30:00'
  };

  assert(alertaData.id !== undefined, 'Alerta should have id');
  assert(alertaData.tipo !== undefined, 'Alerta should have tipo');
  assert(alertaData.mensagem !== undefined, 'Alerta should have mensagem');
  assert(alertaData.criado_em !== undefined, 'Alerta should have criado_em');

  console.log('API response structures: PASS');
}

// Test 10: Dashboard cards rendering with all types
function testDashboardCardsCompleteness() {
  console.log('\n--- Test 10: Dashboard Cards Completeness ---');

  const mockData = {
    total: 100,
    desequilibrio: 20,
    lancamento_orfao: 15,
    cobranca_orfao: 25,
    rateio_invalido: 30,
    timing_anomalia: 10,
    usuario_anomalia: 0
  };

  const html = Auditoria.renderDashboardCards(mockData);

  // All types should be rendered
  assert(html.includes('Total de Anomalias'), 'Should include total card');
  assert(html.includes('Desequil'), 'Should include desequilibrio card');
  assert(html.includes('Lan'), 'Should include lancamento card');
  assert(html.includes('Cobran'), 'Should include cobranca card');
  assert(html.includes('Rateio'), 'Should include rateio card');
  assert(html.includes('Timing'), 'Should include timing card');

  // Colors should be applied
  assert(html.includes('#dc3545') || html.includes('dc3545'), 'Should have red color for desequilibrio');
  assert(html.includes('#fd7e14') || html.includes('fd7e14'), 'Should have orange color for lancamento');
  assert(html.includes('#ffc107') || html.includes('ffc107'), 'Should have yellow color for cobranca');

  console.log('Dashboard cards completeness: PASS');
}

// Run all tests
function runAllTests() {
  console.log('=== Auditoria Dashboard Test Suite ===\n');

  try {
    testDashboardLoad();
    testPeriodoCalculation();
    testAnomaliaTipoClass();
    testAlertaTipoClass();
    testFormatarValor();
    testFormatarData();
    testEscapeHtml();
    testFilterStateManagement();
    testApiResponseStructure();
    testDashboardCardsCompleteness();

    console.log('\n=== All Tests Passed ===');
    return true;
  } catch (err) {
    console.error('\n[FAIL] ' + err.message);
    return false;
  }
}

// Export for Node.js or run in browser
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { runAllTests };
} else if (typeof window !== 'undefined') {
  window.AuditoriaTests = { runAllTests };
}
