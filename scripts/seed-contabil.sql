-- GesCon — seed-contabil.sql
-- Dados iniciais para o sistema contábil em partida dupla
-- População: 20 contas contábeis, 1 exercício inicial, 3 tipos de repartição

INSERT INTO PLANO_CONTAS (PLA_CODIGO, PLA_NOME, PLA_TIPO, PLA_ATIVO)
VALUES
  ('1000', 'Caixa',                    'ATIVO',     1),
  ('1100', 'Banco',                    'ATIVO',     1),
  ('2000', 'Contas a Pagar',           'PASSIVO',   1),
  ('2100', 'Débitos Anteriores',       'PASSIVO',   1),
  ('3000', 'Receita Condominial',      'RECEITA',   1),
  ('3100', 'Multas e Juros',           'RECEITA',   1),
  ('4000', 'Despesa Comum',            'DESPESA',   1),
  ('4100', 'Despesa Extraordinária',   'DESPESA',   1),
  ('4200', 'Água/Luz/Condomínio',      'DESPESA',   1),
  ('4300', 'Limpeza',                  'DESPESA',   1),
  ('4400', 'Segurança',                'DESPESA',   1),
  ('4500', 'Manutenção',               'DESPESA',   1),
  ('4600', 'Seguros',                  'DESPESA',   1),
  ('4700', 'Impostos e Taxas',         'DESPESA',   1),
  ('4800', 'Depreciação',              'DESPESA',   1),
  ('4900', 'Ajustes e Créditos',       'DESPESA',   1),
  ('5000', 'Contas a Receber',         'ATIVO',     1),
  ('6000', 'Capital/Patrimônio',       'PASSIVO',   1),
  ('6100', 'Lucros Acumulados',        'PASSIVO',   1),
  ('7000', 'Outras Contas',            'ATIVO',     1);

INSERT INTO EXERCICIO (EXE_CODIGO, EXE_INICIO, EXE_FIM, EXE_ATIVO, EXE_FECHADO)
VALUES
  ('2025-01', '2025-01-01', '2025-01-31', 1, 0);

INSERT INTO REPARTICAO (REP_CODIGO, REP_NOME, REP_ATIVO)
VALUES
  ('FRACAO', 'Fração Ideal', 1),
  ('METRAGEM', 'Por Metragem', 1),
  ('FIXO', 'Valor Fixo', 1);
