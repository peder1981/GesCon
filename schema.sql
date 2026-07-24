-- GesCon — schema v1. Convenção de exclusão lógica estilo Protheus
-- (R_E_C_N_O_/D_E_L_E_T_/R_E_C_D_E_L_), mesma que o AdvEditor usa.

-- Tabela de metadados SX3 (títulos/tipos de coluna pro FWMBrowse).
CREATE TABLE IF NOT EXISTS SX3 (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    X3_ARQUIVO TEXT NOT NULL,
    X3_ORDEM  INTEGER NOT NULL,
    X3_CAMPO  TEXT NOT NULL,
    X3_TIPO   TEXT NOT NULL,
    X3_TAMANHO INTEGER NOT NULL,
    X3_DECIMAL INTEGER DEFAULT 0,
    X3_QUICK  TEXT DEFAULT 'N',
    X3_VLADB  TEXT DEFAULT '',
    X3_TITULO TEXT
);

CREATE TABLE IF NOT EXISTS CON (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    CON_CODIGO TEXT NOT NULL,
    CON_NOME TEXT NOT NULL,
    CON_CPF TEXT,
    CON_EMAIL TEXT,
    CON_TEL TEXT
);

CREATE TABLE IF NOT EXISTS UNI (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    UNI_CODIGO TEXT NOT NULL,
    UNI_BLOCO TEXT,
    UNI_FRACAO REAL NOT NULL DEFAULT 0,
    UNI_CONDOMINO TEXT
);

CREATE TABLE IF NOT EXISTS DES (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    DES_DESCR TEXT NOT NULL,
    DES_CATEG TEXT,
    DES_VALOR REAL NOT NULL DEFAULT 0,
    DES_COMPET TEXT NOT NULL,
    DES_DTLANC TEXT
);

CREATE TABLE IF NOT EXISTS COB (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    COB_UNIDADE TEXT NOT NULL,
    COB_COMPET TEXT NOT NULL,
    COB_VALOR REAL NOT NULL DEFAULT 0,
    COB_VENCTO TEXT,
    COB_STATUS TEXT NOT NULL DEFAULT 'pendente',
    COB_DTPAG TEXT
);

CREATE TABLE IF NOT EXISTS USR (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    USR_LOGIN TEXT NOT NULL,
    USR_SENHA TEXT NOT NULL
);

-- Tabelas de relatório (Plano 2): snapshot recalculado do zero (DELETE +
-- INSERT) toda vez que o relatório é aberto, mesmo padrão que
-- GcFecharMes já usa pra gravar Cobrança — FWMBrowse só sabe abrir uma
-- tabela física por alias (SELECT rowid ..., UPDATE/DELETE ... WHERE
-- rowid = ?), não dá pra apontar pra uma query parametrizada ou VIEW sem
-- rowid direto. Read-only por convenção, mas tecnicamente editável pela
-- mesma limitação já aceita na tela de Cobranças (ver ARQUITETURA.md).
CREATE TABLE IF NOT EXISTS RPT_INADIM (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    RIN_UNIDADE TEXT,
    RIN_COMPET TEXT,
    RIN_VALOR REAL,
    RIN_VENCTO TEXT,
    RIN_ATRASO INTEGER
);

CREATE TABLE IF NOT EXISTS RPT_EXTRATO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    REX_COMPET TEXT,
    REX_VALOR REAL,
    REX_VENCTO TEXT,
    REX_STATUS TEXT,
    REX_DTPAG TEXT
);

CREATE TABLE IF NOT EXISTS RPT_DESCAT (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    RDC_CATEG TEXT,
    RDC_TOTAL REAL
);

-- GesCon — CFG_BOLETO: configuração do beneficiário para geração de boletos.
-- Uma única linha (estilo MV; INSERT/UPDATE direto).
CREATE TABLE IF NOT EXISTS CFG_BOLETO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    CFG_BANCO TEXT NOT NULL DEFAULT '237',
    CFG_AGENCIA TEXT NOT NULL,
    CFG_CONTA TEXT NOT NULL,
    CFG_COBRT TEXT NOT NULL,
    CFG_CARTEIRA TEXT NOT NULL
);

-- GesCon — GCT_TOKEN: tokens temporários para acesso condômino.
CREATE TABLE IF NOT EXISTS GCT_TOKEN (
    TOKEN TEXT PRIMARY KEY,
    USR_LOGIN TEXT NOT NULL,
    CON_CODIGO TEXT NOT NULL,
    UNI_CODIGO TEXT NOT NULL,
    CRIPTADO TEXT NOT NULL,
    VALIDO_ATE TEXT NOT NULL,
    USADO INTEGER DEFAULT 0,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0
);

-- GesCon — RPT_COND_COBRANCAS: snapshot de cobranças filtrado por unidade
-- (para acesso read-only do condômino via portal).
CREATE TABLE IF NOT EXISTS RPT_COND_COBRANCAS (
    RCC_UNIDADE TEXT NOT NULL,
    RCC_COMPET TEXT NOT NULL,
    RCC_VALOR REAL,
    RCC_VENCTO TEXT,
    RCC_STATUS TEXT,
    RCC_DTPAG TEXT,
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0
);

-- Metadados SX3 (títulos/tipos de coluna pro FWMBrowse — ver browseColumns
-- em pkg/vm/browse.go do AdvPP: sem essas linhas, o browse cai no fallback
-- de mostrar toda coluna física como texto, sem título amigável).
DELETE FROM SX3 WHERE X3_ARQUIVO IN ('CON','UNI','DES','COB','USR','RPT_INADIM','RPT_EXTRATO','RPT_DESCAT','CFG_BOLETO','GCT_TOKEN','RPT_COND_COBRANCAS');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('CON', 1, 'CON_CODIGO', 'C', 10, 0, 'Código'),
('CON', 2, 'CON_NOME',   'C', 60, 0, 'Nome'),
('CON', 3, 'CON_CPF',    'C', 14, 0, 'CPF'),
('CON', 4, 'CON_EMAIL',  'C', 60, 0, 'E-mail'),
('CON', 5, 'CON_TEL',    'C', 20, 0, 'Telefone'),

('UNI', 1, 'UNI_CODIGO',    'C', 10, 0, 'Unidade'),
('UNI', 2, 'UNI_BLOCO',     'C', 10, 0, 'Bloco'),
('UNI', 3, 'UNI_FRACAO',    'N', 8,  4, 'Fração Ideal'),
('UNI', 4, 'UNI_CONDOMINO', 'C', 10, 0, 'Cód. Condômino'),

('DES', 1, 'DES_DESCR',   'C', 80, 0, 'Descrição'),
('DES', 2, 'DES_CATEG',   'C', 30, 0, 'Categoria'),
('DES', 3, 'DES_VALOR',   'N', 14, 2, 'Valor'),
('DES', 4, 'DES_COMPET',  'C', 7,  0, 'Competência'),
('DES', 5, 'DES_DTLANC',  'C', 10, 0, 'Data Lançamento'),

('COB', 1, 'COB_UNIDADE', 'C', 10, 0, 'Unidade'),
('COB', 2, 'COB_COMPET',  'C', 7,  0, 'Competência'),
('COB', 3, 'COB_VALOR',   'N', 14, 2, 'Valor'),
('COB', 4, 'COB_VENCTO',  'C', 10, 0, 'Vencimento'),
('COB', 5, 'COB_STATUS',  'C', 10, 0, 'Status'),
('COB', 6, 'COB_DTPAG',   'C', 10, 0, 'Data Pagamento'),

('RPT_INADIM', 1, 'RIN_UNIDADE', 'C', 10, 0, 'Unidade'),
('RPT_INADIM', 2, 'RIN_COMPET',  'C', 7,  0, 'Competência'),
('RPT_INADIM', 3, 'RIN_VALOR',   'N', 14, 2, 'Valor'),
('RPT_INADIM', 4, 'RIN_VENCTO',  'C', 10, 0, 'Vencimento'),
('RPT_INADIM', 5, 'RIN_ATRASO',  'N', 5,  0, 'Dias de Atraso'),

('RPT_EXTRATO', 1, 'REX_COMPET', 'C', 7,  0, 'Competência'),
('RPT_EXTRATO', 2, 'REX_VALOR',  'N', 14, 2, 'Valor'),
('RPT_EXTRATO', 3, 'REX_VENCTO', 'C', 10, 0, 'Vencimento'),
('RPT_EXTRATO', 4, 'REX_STATUS', 'C', 10, 0, 'Status'),
('RPT_EXTRATO', 5, 'REX_DTPAG',  'C', 10, 0, 'Data Pagamento'),

('RPT_DESCAT', 1, 'RDC_CATEG', 'C', 30, 0, 'Categoria'),
('RPT_DESCAT', 2, 'RDC_TOTAL', 'N', 14, 2, 'Total');

-- GesCon — USR_PERFIL: perfil do usuário (Plano 2).
ALTER TABLE USR ADD COLUMN USR_PERFIL TEXT DEFAULT 'ADMIN';

-- Metadados SX3 para CFG_BOLETO
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('CFG_BOLETO', 1, 'CFG_BANCO',    'C',  4, 0, 'Código do Banco'),
('CFG_BOLETO', 2, 'CFG_AGENCIA',  'C', 10, 0, 'Agência'),
('CFG_BOLETO', 3, 'CFG_CONTA',    'C', 15, 0, 'Conta Corrente'),
('CFG_BOLETO', 4, 'CFG_COBRT',    'C', 15, 0, 'Carta/Cedente ou Convênio'),
('CFG_BOLETO', 5, 'CFG_CARTEIRA', 'C', 10, 0, 'Carteira');

-- Metadados SX3 para GCT_TOKEN
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('GCT_TOKEN', 1, 'TOKEN',      'C', 36, 0, 'Token'),
('GCT_TOKEN', 2, 'USR_LOGIN',  'C', 40, 0, 'Gerado por'),
('GCT_TOKEN', 3, 'CON_CODIGO', 'C', 10, 0, 'Condômino'),
('GCT_TOKEN', 4, 'UNI_CODIGO', 'C', 10, 0, 'Unidade'),
('GCT_TOKEN', 5, 'CRIPTADO',   'C', 19, 0, 'Criado em'),
('GCT_TOKEN', 6, 'VALIDO_ATE', 'C', 19, 0, 'Válido até'),
('GCT_TOKEN', 7, 'USADO',      'N',  1, 0, 'Usado');

-- Metadados SX3 para RPT_COND_COBRANCAS
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('RPT_COND_COBRANCAS', 1, 'RCC_UNIDADE', 'C', 10, 0, 'Unidade'),
('RPT_COND_COBRANCAS', 2, 'RCC_COMPET',  'C',  7, 0, 'Competência'),
('RPT_COND_COBRANCAS', 3, 'RCC_VALOR',   'N', 14, 2, 'Valor'),
('RPT_COND_COBRANCAS', 4, 'RCC_VENCTO',  'C', 10, 0, 'Vencimento'),
('RPT_COND_COBRANCAS', 5, 'RCC_STATUS',  'C', 10, 0, 'Status'),
('RPT_COND_COBRANCAS', 6, 'RCC_DTPAG',   'C', 10, 0, 'Data Pagamento');

-- Metadados SX3 para USR_PERFIL
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('USR', 3, 'USR_PERFIL', 'C', 20, 0, 'Perfil do Usuário');
