-- GesCon — schema v1. Convenção de exclusão lógica estilo Protheus
-- (R_E_C_N_O_/D_E_L_E_T_/R_E_C_D_E_L_), mesma que o AdvEditor usa.

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

-- Metadados SX3 (títulos/tipos de coluna pro FWMBrowse — ver browseColumns
-- em pkg/vm/browse.go do AdvPP: sem essas linhas, o browse cai no fallback
-- de mostrar toda coluna física como texto, sem título amigável).
DELETE FROM SX3 WHERE X3_ARQUIVO IN ('CON','UNI','DES','COB','USR');

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
('COB', 6, 'COB_DTPAG',   'C', 10, 0, 'Data Pagamento');
