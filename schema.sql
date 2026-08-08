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
    FILIAL TEXT,
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
    FILIAL TEXT,
    UNI_CODIGO TEXT NOT NULL,
    UNI_BLOCO TEXT,
    UNI_FRACAO REAL NOT NULL DEFAULT 0,
    UNI_CONDOMINO TEXT,
    UNIQUE(FILIAL, UNI_CODIGO)
);

-- Vínculo unidade->condômino: UNI_CONDOMINO é texto livre na tela (sem
-- combo/lookup), então valida na borda do banco em vez de na UI. Rejeita
-- código que não existe (ou está excluído) em CON, tanto no Incluir quanto
-- no Alterar da tela de Unidades.
CREATE TRIGGER IF NOT EXISTS TRG_UNI_CONDOMINO_INS
BEFORE INSERT ON UNI
WHEN NEW.UNI_CONDOMINO IS NOT NULL AND TRIM(NEW.UNI_CONDOMINO) <> ''
BEGIN
    SELECT RAISE(ABORT, 'Condômino inexistente: cadastre o condômino antes de vincular a unidade.')
    WHERE NOT EXISTS (SELECT 1 FROM CON WHERE CON_CODIGO = NEW.UNI_CONDOMINO AND D_E_L_E_T_ = ' ');
END;

CREATE TRIGGER IF NOT EXISTS TRG_UNI_CONDOMINO_UPD
BEFORE UPDATE OF UNI_CONDOMINO ON UNI
WHEN NEW.UNI_CONDOMINO IS NOT NULL AND TRIM(NEW.UNI_CONDOMINO) <> ''
BEGIN
    SELECT RAISE(ABORT, 'Condômino inexistente: cadastre o condômino antes de vincular a unidade.')
    WHERE NOT EXISTS (SELECT 1 FROM CON WHERE CON_CODIGO = NEW.UNI_CONDOMINO AND D_E_L_E_T_ = ' ');
END;

CREATE TABLE IF NOT EXISTS DES (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT,
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
    FILIAL TEXT,
    COB_UNIDADE TEXT NOT NULL,
    COB_COMPET TEXT NOT NULL,
    COB_VALOR REAL NOT NULL DEFAULT 0,
    COB_VENCTO TEXT,
    COB_STATUS TEXT NOT NULL DEFAULT 'pendente',
    COB_DTPAG TEXT
);

-- Trava de Cobrança: valor, unidade, competência e vencimento só nascem
-- pelo Fechamento Mensal e nunca mudam depois — só Registrar Pagamento
-- (COB_STATUS/COB_DTPAG) toca o registro em diante. A tela de Cobranças é
-- um FWMBrowse cru (Incluir/Alterar/Excluir livres na UI), então a garantia
-- só existe se o banco a impuser.
CREATE TRIGGER IF NOT EXISTS TRG_COB_TRAVA_VALOR
BEFORE UPDATE OF COB_VALOR, COB_UNIDADE, COB_COMPET, COB_VENCTO ON COB
WHEN OLD.COB_VALOR <> NEW.COB_VALOR
    OR OLD.COB_UNIDADE <> NEW.COB_UNIDADE
    OR OLD.COB_COMPET <> NEW.COB_COMPET
    OR IFNULL(OLD.COB_VENCTO, '') <> IFNULL(NEW.COB_VENCTO, '')
BEGIN
    SELECT RAISE(ABORT, 'Cobrança travada: valor, unidade, competência e vencimento não podem ser alterados depois de criados pelo Fechamento. Use Registrar Pagamento para status e data.');
END;

CREATE TRIGGER IF NOT EXISTS TRG_COB_TRAVA_EXCLUSAO
BEFORE UPDATE OF D_E_L_E_T_ ON COB
WHEN NEW.D_E_L_E_T_ = '*' AND OLD.D_E_L_E_T_ = ' '
BEGIN
    SELECT RAISE(ABORT, 'Cobrança não pode ser excluída: é gerada pelo Fechamento Mensal e faz parte do histórico contábil.');
END;

CREATE TABLE IF NOT EXISTS USR (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    USR_LOGIN TEXT NOT NULL,
    USR_SENHA TEXT NOT NULL,
    USR_PERFIL TEXT DEFAULT 'ADMIN'
);

CREATE TABLE IF NOT EXISTS COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    COND_FILIAL TEXT UNIQUE NOT NULL,
    COND_NOME TEXT NOT NULL,
    COND_CNPJ TEXT,
    COND_ENDERECO TEXT,
    COND_ATIVO NUMERIC DEFAULT 1
);

CREATE TABLE IF NOT EXISTS USR_COND (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    USR_LOGIN TEXT NOT NULL,
    FILIAL TEXT NOT NULL,
    UNIQUE(USR_LOGIN, FILIAL)
);

-- Nivel de compartilhamento por tabela, lido pela native FWxFilial do
-- AdvPP (ver AdvPP/docs/superpowers/plans/2026-08-08-multi-filial-implementation.md).
-- 6 = exclusiva por filial (unica opcao usada hoje no GesCon).
CREATE TABLE IF NOT EXISTS X2_FILIAL_COMPART (
    TABELA TEXT PRIMARY KEY,
    NIVEL  INTEGER NOT NULL
);
INSERT OR IGNORE INTO X2_FILIAL_COMPART (TABELA, NIVEL) VALUES
    ('CON', 6), ('UNI', 6), ('DES', 6), ('COB', 6),
    ('RPT_INADIM', 6), ('RPT_EXTRATO', 6), ('RPT_DESCAT', 6),
    ('CFG_BOLETO', 6), ('GCT_TOKEN', 6), ('RPT_COND_COBRANCAS', 6),
    ('PLANO_CONTAS', 6), ('REPARTICAO', 6), ('EXERCICIO', 6),
    ('LANCAMENTOS', 6), ('RATEIO_DETALHE', 6), ('AUDITORIA', 6),
    ('RPT_BALANCETE', 6), ('AVISOS', 6), ('RPT_PORTAL_EXTRATOS', 6),
    ('RPT_PORTAL_AGENDA', 6), ('ANOMALIA_LOG', 6), ('ALERTA', 6),
    ('DASHBOARD_CACHE', 6);

-- Migração automática: base já instalada vira o condomínio nº 1.
INSERT OR IGNORE INTO COND (COND_FILIAL, COND_NOME) VALUES ('010101', 'Condomínio 1');

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
    FILIAL TEXT,
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
    FILIAL TEXT,
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
    FILIAL TEXT,
    RDC_CATEG TEXT,
    RDC_TOTAL REAL
);

-- GesCon — CFG_BOLETO: configuração do beneficiário para geração de boletos.
-- Uma única linha (estilo MV; INSERT/UPDATE direto).
CREATE TABLE IF NOT EXISTS CFG_BOLETO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT,
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
    TOK_PERFIL TEXT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT
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
    R_E_C_D_E_L_ INTEGER DEFAULT 0,
    FILIAL TEXT
);

-- Metadados SX3 (títulos/tipos de coluna pro FWMBrowse — ver browseColumns
-- em pkg/vm/browse.go do AdvPP: sem essas linhas, o browse cai no fallback
-- de mostrar toda coluna física como texto, sem título amigável).
-- Limpa TUDO antes de reinserir: o SX3 e metadado, reconstruido por inteiro
-- por este arquivo. A lista de X3_ARQUIVO que existia aqui cobria 11 das 24
-- tabelas, entao cada bootstrap repetido duplicava as outras 13 -- o banco de
-- desenvolvimento chegou a ter 4 copias de cada coluna de AVISOS.
DELETE FROM SX3;

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
('RPT_DESCAT', 2, 'RDC_TOTAL', 'N', 14, 2, 'Total'),

('COND', 1, 'COND_FILIAL', 'C', 6, 0, 'Filial'),
('COND', 2, 'COND_NOME', 'C', 60, 0, 'Nome'),
('COND', 3, 'COND_CNPJ', 'C', 18, 0, 'CNPJ'),
('COND', 4, 'COND_ENDERECO', 'C', 100, 0, 'Endereço'),
('COND', 5, 'COND_ATIVO', 'N', 1, 0, 'Ativo');

-- USR_PERFIL e TOK_PERFIL nasceram como ALTER TABLE ADD COLUMN. O SQLite nao
-- tem IF NOT EXISTS para ADD COLUMN, entao reaplicar o schema abortava com
-- "duplicate column name" -- e o bootstrap saia 1 sem que ninguem visse.
-- Agora as colunas moram no CREATE TABLE das proprias tabelas.

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

-- ============================================================================
-- Sistema Contábil em Partida Dupla (v2.0)
-- 6 tabelas para suportar lançamentos manuais + automáticos, rateio,
-- fechamento de período com validação D/C, e auditoria.
-- ============================================================================

CREATE TABLE IF NOT EXISTS PLANO_CONTAS (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    FILIAL TEXT,
    PLA_CODIGO TEXT NOT NULL,
    PLA_NOME TEXT NOT NULL,
    PLA_TIPO TEXT NOT NULL,
    PLA_ATIVO NUMERIC DEFAULT 1,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    CHECK(PLA_TIPO IN ('ATIVO', 'PASSIVO', 'RECEITA', 'DESPESA')),
    UNIQUE(FILIAL, PLA_CODIGO)
);
CREATE INDEX IF NOT EXISTS IDX_PLANO_CONTAS_ATIVO ON PLANO_CONTAS(PLA_ATIVO, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS REPARTICAO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    FILIAL TEXT,
    REP_CODIGO TEXT NOT NULL,
    REP_NOME TEXT NOT NULL,
    REP_ATIVO NUMERIC DEFAULT 1,
    REP_DETALHE TEXT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    UNIQUE(FILIAL, REP_CODIGO)
);
CREATE INDEX IF NOT EXISTS IDX_REPARTICAO_ATIVO ON REPARTICAO(REP_ATIVO, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS EXERCICIO (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    FILIAL TEXT,
    EXE_CODIGO TEXT NOT NULL,
    EXE_INICIO DATE NOT NULL,
    EXE_FIM DATE NOT NULL,
    EXE_ATIVO NUMERIC DEFAULT 0,
    EXE_FECHADO NUMERIC DEFAULT 0,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    UNIQUE(FILIAL, EXE_CODIGO)
);
CREATE INDEX IF NOT EXISTS IDX_EXERCICIO_ATIVO ON EXERCICIO(EXE_ATIVO, EXE_FECHADO, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS LANCAMENTOS (
    LAN_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    LAN_DATA DATE NOT NULL,
    LAN_CONTA_DEB TEXT NOT NULL,
    LAN_CONTA_CRED TEXT NOT NULL,
    LAN_VALOR NUMERIC NOT NULL,
    LAN_DESCR TEXT,
    LAN_REFERENCIA NUMERIC,
    LAN_TIPO TEXT NOT NULL,
    LAN_DATA_HORA DATETIME,
    LAN_USUARIO TEXT,
    LAN_EXERCICIO TEXT NOT NULL,
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    FOREIGN KEY(LAN_CONTA_DEB, FILIAL) REFERENCES PLANO_CONTAS(PLA_CODIGO, FILIAL),
    FOREIGN KEY(LAN_CONTA_CRED, FILIAL) REFERENCES PLANO_CONTAS(PLA_CODIGO, FILIAL),
    FOREIGN KEY(LAN_EXERCICIO, FILIAL) REFERENCES EXERCICIO(EXE_CODIGO, FILIAL),
    CHECK(LAN_VALOR > 0),
    CHECK(LAN_TIPO IN ('MANUAL', 'AUTOMATICO_DESPESA', 'AUTOMATICO_RATEIO')),
    CHECK(LAN_CONTA_DEB != LAN_CONTA_CRED)
);
CREATE INDEX IF NOT EXISTS IDX_LANCAMENTOS_EXERCICIO ON LANCAMENTOS(LAN_EXERCICIO, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_LANCAMENTOS_TIPO ON LANCAMENTOS(LAN_TIPO, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_LANCAMENTOS_REFERENCIA ON LANCAMENTOS(LAN_REFERENCIA, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS RATEIO_DETALHE (
    RAT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    RAT_LANCAMENTO INTEGER NOT NULL,
    RAT_UNIDADE TEXT NOT NULL,
    RAT_VALOR NUMERIC NOT NULL,
    RAT_PERCENTUAL NUMERIC,
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    FOREIGN KEY(RAT_LANCAMENTO) REFERENCES LANCAMENTOS(LAN_ID),
    FOREIGN KEY(RAT_UNIDADE, FILIAL) REFERENCES UNI(UNI_CODIGO, FILIAL),
    CHECK(RAT_VALOR > 0)
);
CREATE INDEX IF NOT EXISTS IDX_RATEIO_LANCAMENTO ON RATEIO_DETALHE(RAT_LANCAMENTO, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_RATEIO_UNIDADE ON RATEIO_DETALHE(RAT_UNIDADE, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS AUDITORIA (
    AUD_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    AUD_DATA_HORA DATETIME NOT NULL,
    AUD_TIPO TEXT NOT NULL,
    AUD_DESCRICAO TEXT,
    AUD_SEVERIDADE TEXT NOT NULL,
    AUD_RECNO_LAN NUMERIC,
    AUD_RECNO_COB NUMERIC,
    AUD_EXERCICIO TEXT,
    R_E_C_N_O_ INTEGER,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    CHECK(AUD_SEVERIDADE IN ('CRITICA', 'AVISO', 'INFO')),
    CHECK(AUD_TIPO IN ('DESEQUILIBRIO_CONTABIL', 'COB_ORFAO', 'LAN_ORFAO', 'OUTRO'))
);
CREATE INDEX IF NOT EXISTS IDX_AUDITORIA_EXERCICIO ON AUDITORIA(AUD_EXERCICIO, AUD_SEVERIDADE, D_E_L_E_T_);

CREATE TABLE IF NOT EXISTS RPT_BALANCETE (
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    RPT_EXERCICIO TEXT NOT NULL,
    RPT_RECEITAS NUMERIC,
    RPT_DESPESAS NUMERIC,
    RPT_SALDO NUMERIC,
    RPT_DATA_GERACAO DATETIME,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    UNIQUE(FILIAL, RPT_EXERCICIO, D_E_L_E_T_)
);

-- Metadados SX3 para PLANO_CONTAS
DELETE FROM SX3 WHERE X3_ARQUIVO IN ('PLANO_CONTAS','REPARTICAO','EXERCICIO','LANCAMENTOS','RATEIO_DETALHE','AUDITORIA','RPT_BALANCETE');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('PLANO_CONTAS', 1, 'PLA_CODIGO', 'C', 10, 0, 'Código Conta'),
('PLANO_CONTAS', 2, 'PLA_NOME',   'C', 80, 0, 'Nome Conta'),
('PLANO_CONTAS', 3, 'PLA_TIPO',   'C', 15, 0, 'Tipo'),
('PLANO_CONTAS', 4, 'PLA_ATIVO',  'N',  1, 0, 'Ativo'),

('REPARTICAO', 1, 'REP_CODIGO',   'C', 20, 0, 'Código Repartição'),
('REPARTICAO', 2, 'REP_NOME',     'C', 80, 0, 'Nome Repartição'),
('REPARTICAO', 3, 'REP_ATIVO',    'N',  1, 0, 'Ativo'),
('REPARTICAO', 4, 'REP_DETALHE',  'C', 200, 0, 'Detalhes'),

('EXERCICIO', 1, 'EXE_CODIGO',   'C',  7, 0, 'Código Exercício'),
('EXERCICIO', 2, 'EXE_INICIO',   'D', 10, 0, 'Data Início'),
('EXERCICIO', 3, 'EXE_FIM',      'D', 10, 0, 'Data Fim'),
('EXERCICIO', 4, 'EXE_ATIVO',    'N',  1, 0, 'Ativo'),
('EXERCICIO', 5, 'EXE_FECHADO',  'N',  1, 0, 'Fechado'),

('LANCAMENTOS', 1, 'LAN_DATA',       'D', 10, 0, 'Data Lançamento'),
('LANCAMENTOS', 2, 'LAN_CONTA_DEB',  'C', 10, 0, 'Conta Débito'),
('LANCAMENTOS', 3, 'LAN_CONTA_CRED', 'C', 10, 0, 'Conta Crédito'),
('LANCAMENTOS', 4, 'LAN_VALOR',      'N', 14, 2, 'Valor'),
('LANCAMENTOS', 5, 'LAN_DESCR',      'C', 200, 0, 'Descrição'),
('LANCAMENTOS', 6, 'LAN_TIPO',       'C', 20, 0, 'Tipo Lançamento'),
('LANCAMENTOS', 7, 'LAN_EXERCICIO',  'C',  7, 0, 'Exercício'),
('LANCAMENTOS', 8, 'LAN_DATA_HORA',  'C', 19, 0, 'Data/Hora'),
('LANCAMENTOS', 9, 'LAN_USUARIO',    'C', 40, 0, 'Usuário'),

('RATEIO_DETALHE', 1, 'RAT_LANCAMENTO',  'N',  10, 0, 'ID Lançamento'),
('RATEIO_DETALHE', 2, 'RAT_UNIDADE',     'C',  10, 0, 'Unidade'),
('RATEIO_DETALHE', 3, 'RAT_VALOR',       'N',  14, 2, 'Valor Rateado'),
('RATEIO_DETALHE', 4, 'RAT_PERCENTUAL',  'N',   8, 4, 'Percentual'),

('AUDITORIA', 1, 'AUD_DATA_HORA',   'C', 19, 0, 'Data/Hora'),
('AUDITORIA', 2, 'AUD_TIPO',        'C', 25, 0, 'Tipo Anomalia'),
('AUDITORIA', 3, 'AUD_DESCRICAO',   'C', 200, 0, 'Descrição'),
('AUDITORIA', 4, 'AUD_SEVERIDADE',  'C', 10, 0, 'Severidade'),
('AUDITORIA', 5, 'AUD_EXERCICIO',   'C',  7, 0, 'Exercício'),

('RPT_BALANCETE', 1, 'RPT_EXERCICIO',      'C',  7, 0, 'Exercício'),
('RPT_BALANCETE', 2, 'RPT_RECEITAS',       'N', 14, 2, 'Receitas'),
('RPT_BALANCETE', 3, 'RPT_DESPESAS',       'N', 14, 2, 'Despesas'),
('RPT_BALANCETE', 4, 'RPT_SALDO',          'N', 14, 2, 'Saldo'),
('RPT_BALANCETE', 5, 'RPT_DATA_GERACAO',   'C', 19, 0, 'Data Geração');

-- Os blocos de semente que existiam aqui (plano de contas padrão, tipos de
-- rateio, exercício 2025-01, 20 unidades de teste) foram REMOVIDOS ao
-- multi-condomínio: com UNIQUE composto (FILIAL, campo), não existe um
-- FILIAL "neutro" que sirva de chave pra INSERT OR IGNORE deduplicar contra
-- si mesmo sem também colidir com dado real. Testado com FILIAL=NULL
-- (colisão nunca detectada — todo boot cria 20 linhas fantasma novas,
-- crescimento sem fim) e com FILIAL='SEED' fixo (dedupla certo, mas todo
-- código hoje ainda lê UNI/PLANO_CONTAS/etc. sem filtrar por FILIAL —
-- Tasks 5-9 deste plano — então as linhas fantasma entravam na conta do
-- fechamento de um condomínio real, dobrando unidades e duplicando
-- exercício ativo). Nenhuma das duas é segura antes que todo o app filtre
-- por FILIAL. Os testes que dependiam de unidades/contas pré-existentes já
-- criam as próprias (INSERT OR IGNORE com D_E_L_E_T_ explícito, ex.
-- tests/portal-v2_test.prw) — nenhum contava com a semente daqui.

-- ============================================================================
-- Portal do Condômino v2 — Tabelas de snapshot (avisos, extratos, agenda)
-- ============================================================================

-- AVISOS: Mural de avisos (anúncios publicados pelos admin)
CREATE TABLE IF NOT EXISTS AVISOS (
    AVI_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    AVI_TITULO TEXT NOT NULL,
    AVI_CORPO TEXT NOT NULL,
    AVI_DATA_CRIACAO DATETIME DEFAULT CURRENT_TIMESTAMP,
    AVI_ATIVO INTEGER DEFAULT 1 CHECK(AVI_ATIVO IN (0, 1)),
    R_E_C_N_O_ INTEGER UNIQUE,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT
);
CREATE INDEX IF NOT EXISTS IDX_AVISOS_ATIVO ON AVISOS(AVI_ATIVO, D_E_L_E_T_);

-- RPT_PORTAL_EXTRATOS: Snapshot de faturas por unidade/mês
-- Regenerado 100% (DELETE + INSERT) a cada fechamento de período
CREATE TABLE IF NOT EXISTS RPT_PORTAL_EXTRATOS (
    REX_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    REX_COMPETENCIA TEXT NOT NULL,
    REX_UNIDADE TEXT NOT NULL,
    REX_VALOR NUMERIC NOT NULL,
    REX_VENCIMENTO DATE NOT NULL,
    REX_STATUS TEXT DEFAULT 'PENDENTE' CHECK(REX_STATUS IN ('PENDENTE', 'PAGO')),
    REX_DATA_PAGAMENTO DATE,
    R_E_C_N_O_ INTEGER UNIQUE,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    UNIQUE(FILIAL, REX_COMPETENCIA, REX_UNIDADE, D_E_L_E_T_),
    FOREIGN KEY(REX_UNIDADE, FILIAL) REFERENCES UNI(UNI_CODIGO, FILIAL)
);
CREATE INDEX IF NOT EXISTS IDX_RPT_PORTAL_EXTRATOS_UNIDADE ON RPT_PORTAL_EXTRATOS(REX_UNIDADE, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_RPT_PORTAL_EXTRATOS_COMPETENCIA ON RPT_PORTAL_EXTRATOS(REX_COMPETENCIA, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_RPT_PORTAL_EXTRATOS_STATUS ON RPT_PORTAL_EXTRATOS(REX_STATUS, D_E_L_E_T_);

-- RPT_PORTAL_AGENDA: Próximos vencimentos (próximos 12 meses)
-- Regenerado 100% (DELETE + INSERT) a cada fechamento de período
CREATE TABLE IF NOT EXISTS RPT_PORTAL_AGENDA (
    REA_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    REA_UNIDADE TEXT NOT NULL,
    REA_COMPETENCIA TEXT NOT NULL,
    REA_VENCIMENTO DATE NOT NULL,
    REA_VALOR NUMERIC NOT NULL,
    R_E_C_N_O_ INTEGER UNIQUE,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ NUMERIC,
    FILIAL TEXT,
    FOREIGN KEY(REA_UNIDADE, FILIAL) REFERENCES UNI(UNI_CODIGO, FILIAL)
);
CREATE INDEX IF NOT EXISTS IDX_RPT_PORTAL_AGENDA_UNIDADE ON RPT_PORTAL_AGENDA(REA_UNIDADE, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_RPT_PORTAL_AGENDA_VENCIMENTO ON RPT_PORTAL_AGENDA(REA_VENCIMENTO, D_E_L_E_T_);

-- Metadados SX3 para AVISOS
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('AVISOS', 1, 'AVI_ID',            'N',  10, 0, 'ID Aviso'),
('AVISOS', 2, 'AVI_TITULO',        'C', 255, 0, 'Título'),
('AVISOS', 3, 'AVI_CORPO',         'M',   0, 0, 'Corpo'),
('AVISOS', 4, 'AVI_DATA_CRIACAO',  'C',  19, 0, 'Data Criação'),
('AVISOS', 5, 'AVI_ATIVO',         'N',   1, 0, 'Ativo');

-- Metadados SX3 para RPT_PORTAL_EXTRATOS
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('RPT_PORTAL_EXTRATOS', 1, 'REX_ID',              'N',  10, 0, 'ID Extrato'),
('RPT_PORTAL_EXTRATOS', 2, 'REX_COMPETENCIA',    'C',   7, 0, 'Competência'),
('RPT_PORTAL_EXTRATOS', 3, 'REX_UNIDADE',        'C',  10, 0, 'Unidade'),
('RPT_PORTAL_EXTRATOS', 4, 'REX_VALOR',          'N',  14, 2, 'Valor'),
('RPT_PORTAL_EXTRATOS', 5, 'REX_VENCIMENTO',     'D',  10, 0, 'Vencimento'),
('RPT_PORTAL_EXTRATOS', 6, 'REX_STATUS',         'C',  10, 0, 'Status'),
('RPT_PORTAL_EXTRATOS', 7, 'REX_DATA_PAGAMENTO', 'D',  10, 0, 'Data Pagamento');

-- Metadados SX3 para RPT_PORTAL_AGENDA
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('RPT_PORTAL_AGENDA', 1, 'REA_ID',          'N',  10, 0, 'ID Agenda'),
('RPT_PORTAL_AGENDA', 2, 'REA_UNIDADE',     'C',  10, 0, 'Unidade'),
('RPT_PORTAL_AGENDA', 3, 'REA_COMPETENCIA', 'C',   7, 0, 'Competência'),
('RPT_PORTAL_AGENDA', 4, 'REA_VENCIMENTO',  'D',  10, 0, 'Vencimento'),
('RPT_PORTAL_AGENDA', 5, 'REA_VALOR',       'N',  14, 2, 'Valor');

-- ANOMALIA_LOG: histÃ³rico de anomalias detectadas
CREATE TABLE IF NOT EXISTS ANOMALIA_LOG (
  ANL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
  ANL_TIPO TEXT NOT NULL,
  ANL_PERIODO TEXT NOT NULL,
  ANL_UNIDADE TEXT,
  ANL_VALOR NUMERIC,
  ANL_DESCRICAO TEXT,
  ANL_LANCAMENTO_ID INTEGER,
  ANL_COBRANCA_ID INTEGER,
  ANL_CRIADO_EM DATETIME DEFAULT CURRENT_TIMESTAMP,
  ANL_RESOLVIDO_EM DATETIME,
  ANL_STATUS TEXT DEFAULT 'ABERTO' CHECK(ANL_STATUS IN ('ABERTO', 'RESOLVIDO', 'IGNORADO')),
  R_E_C_N_O_ INTEGER UNIQUE,
  D_E_L_E_T_ TEXT DEFAULT ' ',
  R_E_C_D_E_L_ NUMERIC,
  FILIAL TEXT
);
CREATE INDEX IF NOT EXISTS IDX_ANOMALIA_TIPO ON ANOMALIA_LOG(ANL_TIPO, D_E_L_E_T_);
CREATE INDEX IF NOT EXISTS IDX_ANOMALIA_PERIODO ON ANOMALIA_LOG(ANL_PERIODO, D_E_L_E_T_);

-- ALERTA: notificaÃ§Ãµes crÃ­ticas em tempo real
CREATE TABLE IF NOT EXISTS ALERTA (
  ALT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
  ALT_TIPO TEXT NOT NULL CHECK(ALT_TIPO IN ('CRITICO', 'AVISO', 'INFO')),
  ALT_ANOMALIA_ID INTEGER,
  ALT_MENSAGEM TEXT NOT NULL,
  ALT_CRIADO_EM DATETIME DEFAULT CURRENT_TIMESTAMP,
  ALT_VISTO INTEGER DEFAULT 0,
  ALT_VISTO_EM DATETIME,
  R_E_C_N_O_ INTEGER UNIQUE,
  D_E_L_E_T_ TEXT DEFAULT ' ',
  R_E_C_D_E_L_ NUMERIC,
  FILIAL TEXT,
  FOREIGN KEY(ALT_ANOMALIA_ID) REFERENCES ANOMALIA_LOG(ANL_ID)
);
CREATE INDEX IF NOT EXISTS IDX_ALERTA_TIPO ON ALERTA(ALT_TIPO, ALT_VISTO, D_E_L_E_T_);

-- DASHBOARD_CACHE: snapshot diÃ¡rio para performance
CREATE TABLE IF NOT EXISTS DASHBOARD_CACHE (
  DSH_ID INTEGER PRIMARY KEY AUTOINCREMENT,
  DSH_DATA DATE NOT NULL,
  DSH_PERIODO TEXT NOT NULL,
  DSH_ANOMALIAS_TOTAL NUMERIC,
  DSH_DESEQUILIBRIO_COUNT NUMERIC,
  DSH_LAN_ORFAO_COUNT NUMERIC,
  DSH_COB_ORFAO_COUNT NUMERIC,
  DSH_RATEIO_INVALID_COUNT NUMERIC,
  DSH_TIMING_COUNT NUMERIC,
  DSH_USUARIO_COUNT NUMERIC,
  DSH_JSON TEXT,
  DSH_ATUALIZADO_EM DATETIME,
  R_E_C_N_O_ INTEGER UNIQUE,
  D_E_L_E_T_ TEXT DEFAULT ' ',
  R_E_C_D_E_L_ NUMERIC,
  FILIAL TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS IDX_DASHBOARD_DATA_PERIODO ON DASHBOARD_CACHE(FILIAL, DSH_DATA, DSH_PERIODO, D_E_L_E_T_);


-- Metadados SX3 para TOK_PERFIL
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('GCT_TOKEN', 8, 'TOK_PERFIL', 'C', 20, 0, 'Perfil do Token');


-- ============================================================================
-- Metadados SX3 das tabelas de auditoria (Portal v3)
-- Sem estas linhas o FWMBrowse abre ANOMALIA_LOG, ALERTA e DASHBOARD_CACHE
-- sem coluna nenhuma -- as telas do menu Auditoria dependem disto.
-- ============================================================================

DELETE FROM SX3 WHERE X3_ARQUIVO IN ('ANOMALIA_LOG','ALERTA','DASHBOARD_CACHE');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('ANOMALIA_LOG', 1, 'ANL_ID',            'N', 10, 0, 'ID'),
('ANOMALIA_LOG', 2, 'ANL_TIPO',          'C', 40, 0, 'Tipo'),
('ANOMALIA_LOG', 3, 'ANL_PERIODO',       'C',  7, 0, 'Período'),
('ANOMALIA_LOG', 4, 'ANL_UNIDADE',       'C', 20, 0, 'Unidade'),
('ANOMALIA_LOG', 5, 'ANL_VALOR',         'N', 14, 2, 'Valor'),
('ANOMALIA_LOG', 6, 'ANL_DESCRICAO',     'C',255, 0, 'Descrição'),
('ANOMALIA_LOG', 7, 'ANL_LANCAMENTO_ID', 'N', 10, 0, 'Lançamento'),
('ANOMALIA_LOG', 8, 'ANL_COBRANCA_ID',   'N', 10, 0, 'Cobrança'),
('ANOMALIA_LOG', 9, 'ANL_CRIADO_EM',     'C', 19, 0, 'Detectada em'),
('ANOMALIA_LOG',10, 'ANL_RESOLVIDO_EM',  'C', 19, 0, 'Resolvida em'),
('ANOMALIA_LOG',11, 'ANL_STATUS',        'C', 20, 0, 'Status');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('ALERTA', 1, 'ALT_ID',          'N', 10, 0, 'ID'),
('ALERTA', 2, 'ALT_TIPO',        'C', 20, 0, 'Tipo'),
('ALERTA', 3, 'ALT_ANOMALIA_ID', 'N', 10, 0, 'Anomalia'),
('ALERTA', 4, 'ALT_MENSAGEM',    'C',255, 0, 'Mensagem'),
('ALERTA', 5, 'ALT_CRIADO_EM',   'C', 19, 0, 'Criado em'),
('ALERTA', 6, 'ALT_VISTO',       'N',  1, 0, 'Visto'),
('ALERTA', 7, 'ALT_VISTO_EM',    'C', 19, 0, 'Visto em');

INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('DASHBOARD_CACHE', 1, 'DSH_ID',                  'N', 10, 0, 'ID'),
('DASHBOARD_CACHE', 2, 'DSH_DATA',                'C', 10, 0, 'Data'),
('DASHBOARD_CACHE', 3, 'DSH_PERIODO',             'C',  7, 0, 'Período'),
('DASHBOARD_CACHE', 4, 'DSH_ANOMALIAS_TOTAL',     'N', 10, 0, 'Total'),
('DASHBOARD_CACHE', 5, 'DSH_DESEQUILIBRIO_COUNT', 'N', 10, 0, 'Desequilíbrio'),
('DASHBOARD_CACHE', 6, 'DSH_LAN_ORFAO_COUNT',     'N', 10, 0, 'Lanç. órfãos'),
('DASHBOARD_CACHE', 7, 'DSH_COB_ORFAO_COUNT',     'N', 10, 0, 'Cobr. órfãs'),
('DASHBOARD_CACHE', 8, 'DSH_RATEIO_INVALID_COUNT','N', 10, 0, 'Rateio inválido'),
('DASHBOARD_CACHE', 9, 'DSH_TIMING_COUNT',        'N', 10, 0, 'Timing'),
('DASHBOARD_CACHE',10, 'DSH_USUARIO_COUNT',       'N', 10, 0, 'Usuário'),
('DASHBOARD_CACHE',11, 'DSH_ATUALIZADO_EM',       'C', 19, 0, 'Atualizado em');

-- USR_LOGIN faltava: o browse de usuarios abria com uma coluna so.
-- USR_SENHA fica fora de proposito -- hash nao se mostra em tela.
INSERT INTO SX3 (X3_ARQUIVO, X3_ORDEM, X3_CAMPO, X3_TIPO, X3_TAMANHO, X3_DECIMAL, X3_TITULO) VALUES
('USR', 1, 'USR_LOGIN', 'C', 50, 0, 'Login');
