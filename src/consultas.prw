// src/consultas.prw — consultas da interface: cada função devolve
// {colunas, linhas} prontas para uma PoTable, lidas direto do banco e
// filtradas pela filial (condomínio) da sessão. Substituem as tabelas de
// rascunho RPT_*, que eram compartilhadas por condomínio: na web, sessões
// simultâneas sobrescreviam umas às outras (no portal, um condômino podia
// ver as cobranças de outra unidade).
//
// Coluna: {campo, rótulo[, formato]}: "R$" (reais, à direita), "number",
// "data" (DD/MM/AAAA), "comp" (competência MM/AAAA).
#include "totvs.ch"

/*/{Protheus.doc} GcConsulta
    Executa a consulta e monta as linhas na ordem das colunas. Valores
    numéricos marcados com "R$" na definição saem formatados em reais.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param aCols, array, {{campo, rótulo[, tipo]}, ...}; campo em maiúsculas como na consulta
    @param cSql, character, consulta
    @return array, {aColunasPoTable, aLinhas}
*/
User Function GcConsulta(aCols, cSql)
    Local aRows := TCSqlQuery(cSql) as array
    Local aDef  := {} as array
    Local aLin  := {} as array
    Local aRow  := {} as array
    Local xVal  := Nil
    Local nI    := 0 as numeric
    Local nJ    := 0 as numeric

    For nJ := 1 To Len(aCols)
        // "R$" alinha como número; "data"/"comp" só mudam a formatação (um
        // tipo desconhecido para a PoTable esconde a coluna).
        If Len(aCols[nJ]) >= 3 .And. (aCols[nJ][3] == "R$" .Or. aCols[nJ][3] == "number")
            aAdd(aDef, {Lower(aCols[nJ][1]), aCols[nJ][2], "number"})
        Else
            aAdd(aDef, {Lower(aCols[nJ][1]), aCols[nJ][2]})
        EndIf
    Next nJ
    For nI := 1 To Len(aRows)
        aRow := {}
        For nJ := 1 To Len(aCols)
            xVal := aRows[nI][aCols[nJ][1]]
            If ValType(xVal) != "C"
                xVal := cValToChar(xVal)
            EndIf
            If Len(aCols[nJ]) >= 3 .And. aCols[nJ][3] == "R$"
                xVal := AllTrim(Transform(Val(xVal), "@E 999,999,999.99"))
            ElseIf Len(aCols[nJ]) >= 3 .And. aCols[nJ][3] == "data"
                xVal := GcDataBr(xVal)
            ElseIf Len(aCols[nJ]) >= 3 .And. aCols[nJ][3] == "comp" .And. Len(AllTrim(xVal)) == 7
                xVal := Right(AllTrim(xVal), 2) + "/" + Left(AllTrim(xVal), 4)
            EndIf
            aAdd(aRow, AllTrim(xVal))
        Next nJ
        aAdd(aLin, aRow)
    Next nI
Return {aDef, aLin}

/*/{Protheus.doc} GcDataBr
    "AAAA-MM-DD[...]" ou "AAAAMMDD" para "DD/MM/AAAA"; outro formato volta
    como veio.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cData, character, data em texto
    @return character, data brasileira
*/
User Function GcDataBr(cData)
    Local c := AllTrim(cData) as character

    If Len(c) >= 10 .And. SubStr(c, 5, 1) == "-"
        Return SubStr(c, 9, 2) + "/" + SubStr(c, 6, 2) + "/" + Left(c, 4)
    EndIf
    If Len(c) == 8 .And. !("/" $ c) .And. !("-" $ c)
        Return Right(c, 2) + "/" + SubStr(c, 5, 2) + "/" + Left(c, 4)
    EndIf
Return c

/*/{Protheus.doc} GcQPortalCobrancas
    Cobranças de uma unidade (portal do condômino), da filial da sessão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cUnidade, character, unidade do token
    @return array, {colunas, linhas}; a 1a coluna é o R_E_C_N_O_ (para o boleto)
*/
User Function GcQPortalCobrancas(cUnidade)
Return GcConsulta({{"R_E_C_N_O_", "Nº"}, {"COB_COMPET", "Competência", "comp"}, {"COB_VALOR", "Valor (R$)", "R$"}, ;
    {"COB_VENCTO", "Vencimento", "data"}, {"COB_STATUS", "Situação"}, {"COB_DTPAG", "Pago em", "data"}}, ;
    "SELECT R_E_C_N_O_, COB_COMPET, COB_VALOR, COB_VENCTO, COB_STATUS, IFNULL(COB_DTPAG, '') AS COB_DTPAG FROM COB " + ;
    "WHERE COB_UNIDADE = '" + GcSqlLit(cUnidade) + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' " + ;
    "ORDER BY COB_VENCTO DESC")

/*/{Protheus.doc} GcQAvisosAtivos
    Avisos ativos do condomínio da sessão, mais recentes primeiro.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQAvisosAtivos()
Return GcConsulta({{"AVI_ID", "Nº"}, {"AVI_DATA_CRIACAO", "Data", "data"}, {"AVI_TITULO", "Título"}, {"AVI_CORPO", "Aviso"}}, ;
    "SELECT AVI_ID, AVI_DATA_CRIACAO, AVI_TITULO, AVI_CORPO FROM AVISOS WHERE AVI_ATIVO = 1 AND D_E_L_E_T_ = ' ' " + ;
    "AND FILIAL = '" + GcSqlLit(FWxFilial('AVISOS')) + "' ORDER BY AVI_DATA_CRIACAO DESC")

/*/{Protheus.doc} GcQCondominos
    Condôminos do condomínio da sessão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQCondominos()
Return GcConsulta({{"CON_CODIGO", "Código"}, {"CON_NOME", "Nome"}, {"CON_CPF", "CPF/CNPJ"}, {"CON_EMAIL", "E-mail"}, {"CON_TEL", "Telefone"}}, ;
    "SELECT CON_CODIGO, CON_NOME, IFNULL(CON_CPF, '') AS CON_CPF, IFNULL(CON_EMAIL, '') AS CON_EMAIL, IFNULL(CON_TEL, '') AS CON_TEL " + ;
    "FROM CON WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('CON')) + "' ORDER BY CON_NOME")

/*/{Protheus.doc} GcQUnidades
    Unidades do condomínio da sessão, com o condômino e a fração em %.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQUnidades()
Return GcConsulta({{"UNI_CODIGO", "Unidade"}, {"UNI_BLOCO", "Bloco"}, {"UNI_FRACAO", "Fração ideal", "number"}, ;
    {"PERC", "%", "number"}, {"UNI_CONDOMINO", "Condômino"}, {"CON_NOME", "Nome"}}, ;
    "SELECT U.UNI_CODIGO, IFNULL(U.UNI_BLOCO, '') AS UNI_BLOCO, U.UNI_FRACAO, printf('%.4f', U.UNI_FRACAO * 100) AS PERC, " + ;
    "IFNULL(U.UNI_CONDOMINO, '') AS UNI_CONDOMINO, IFNULL(C.CON_NOME, '') AS CON_NOME FROM UNI U " + ;
    "LEFT JOIN CON C ON C.CON_CODIGO = U.UNI_CONDOMINO AND C.FILIAL = U.FILIAL AND C.D_E_L_E_T_ = ' ' " + ;
    "WHERE U.D_E_L_E_T_ = ' ' AND U.FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "' ORDER BY U.UNI_BLOCO, U.UNI_CODIGO")

/*/{Protheus.doc} GcQDespesas
    Despesas do condomínio da sessão (mais recentes primeiro), com a marca
    de competência fechada.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}; 1a coluna R_E_C_N_O_
*/
User Function GcQDespesas()
Return GcConsulta({{"R_E_C_N_O_", "Nº"}, {"DES_COMPET", "Competência"}, {"DES_DESCR", "Descrição"}, {"DES_CATEG", "Categoria"}, ;
    {"DES_VALOR", "Valor (R$)", "R$"}, {"SITUACAO", "Situação"}}, ;
    "SELECT D.R_E_C_N_O_, D.DES_COMPET, D.DES_DESCR, IFNULL(D.DES_CATEG, '') AS DES_CATEG, D.DES_VALOR, " + ;
    "CASE WHEN EXISTS (SELECT 1 FROM COB C WHERE C.COB_COMPET = D.DES_COMPET AND C.FILIAL = D.FILIAL AND C.D_E_L_E_T_ = ' ') " + ;
    "THEN 'fechada' ELSE 'aberta' END AS SITUACAO FROM DES D " + ;
    "WHERE D.D_E_L_E_T_ = ' ' AND D.FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "' ORDER BY D.DES_COMPET DESC, D.R_E_C_N_O_ DESC LIMIT 1000")

/*/{Protheus.doc} GcQCondominios
    Condomínios ativos (cadastro do super administrador).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQCondominios()
Return GcConsulta({{"COND_FILIAL", "Código"}, {"COND_NOME", "Nome"}, {"COND_CNPJ", "CNPJ"}, {"COND_ENDERECO", "Endereço"}}, ;
    "SELECT COND_FILIAL, COND_NOME, IFNULL(COND_CNPJ, '') AS COND_CNPJ, IFNULL(COND_ENDERECO, '') AS COND_ENDERECO " + ;
    "FROM COND WHERE COND_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY COND_NOME")

/*/{Protheus.doc} GcQCobrancas
    Cobranças do condomínio da sessão, com o condômino.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cStatus, character, "" (todas), "pendente", "atrasado" ou "pago"
    @return array, {colunas, linhas}; 1a coluna R_E_C_N_O_
*/
User Function GcQCobrancas(cStatus)
    Local cFiltro := "" as character

    If !Empty(cStatus)
        cFiltro := " AND C.COB_STATUS = '" + GcSqlLit(cStatus) + "'"
    EndIf
Return GcConsulta({{"R_E_C_N_O_", "Nº"}, {"COB_COMPET", "Competência", "comp"}, {"COB_UNIDADE", "Unidade"}, {"CON_NOME", "Condômino"}, ;
    {"COB_VALOR", "Valor (R$)", "R$"}, {"COB_VENCTO", "Vencimento", "data"}, {"COB_STATUS", "Situação"}, {"COB_DTPAG", "Pago em", "data"}}, ;
    "SELECT C.R_E_C_N_O_, C.COB_COMPET, C.COB_UNIDADE, IFNULL(N.CON_NOME, '') AS CON_NOME, C.COB_VALOR, C.COB_VENCTO, C.COB_STATUS, " + ;
    "IFNULL(C.COB_DTPAG, '') AS COB_DTPAG FROM COB C " + ;
    "LEFT JOIN UNI U ON U.UNI_CODIGO = C.COB_UNIDADE AND U.FILIAL = C.FILIAL AND U.D_E_L_E_T_ = ' ' " + ;
    "LEFT JOIN CON N ON N.CON_CODIGO = U.UNI_CONDOMINO AND N.FILIAL = C.FILIAL AND N.D_E_L_E_T_ = ' ' " + ;
    "WHERE C.D_E_L_E_T_ = ' ' AND C.FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'" + cFiltro + ;
    " ORDER BY C.COB_VENCTO DESC, C.COB_UNIDADE LIMIT 2000")

/*/{Protheus.doc} GcQCompetencias
    Competências fechadas: unidades cobradas, total, recebido e em aberto.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQCompetencias()
Return GcConsulta({{"COB_COMPET", "Competência", "comp"}, {"QTD", "Unidades", "number"}, {"TOTAL", "Total (R$)", "R$"}, ;
    {"PAGO", "Recebido (R$)", "R$"}, {"ABERTO", "Em aberto (R$)", "R$"}, {"VENC", "Vencimento", "data"}}, ;
    "SELECT COB_COMPET, COUNT(*) AS QTD, SUM(COB_VALOR) AS TOTAL, " + ;
    "SUM(CASE WHEN COB_STATUS = 'pago' THEN COB_VALOR ELSE 0 END) AS PAGO, " + ;
    "SUM(CASE WHEN COB_STATUS <> 'pago' THEN COB_VALOR ELSE 0 END) AS ABERTO, MIN(COB_VENCTO) AS VENC FROM COB " + ;
    "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' GROUP BY COB_COMPET ORDER BY COB_COMPET DESC")

/*/{Protheus.doc} GcQAvisos
    Avisos do condomínio da sessão (ativos e arquivados).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}; 1a coluna AVI_ID
*/
User Function GcQAvisos()
Return GcConsulta({{"AVI_ID", "Nº"}, {"AVI_DATA_CRIACAO", "Data", "data"}, {"AVI_TITULO", "Título"}, {"AVI_CORPO", "Aviso"}, {"SIT", "Situação"}}, ;
    "SELECT AVI_ID, AVI_DATA_CRIACAO, AVI_TITULO, AVI_CORPO, CASE WHEN AVI_ATIVO = 1 THEN 'publicado' ELSE 'arquivado' END AS SIT " + ;
    "FROM AVISOS WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('AVISOS')) + "' ORDER BY AVI_ATIVO DESC, AVI_DATA_CRIACAO DESC")

/*/{Protheus.doc} GcQTokens
    Tokens do portal ainda válidos e não usados (sem mostrar o token).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQTokens()
Return GcConsulta({{"UNI_CODIGO", "Unidade"}, {"CON_CODIGO", "Condômino"}, {"USR_LOGIN", "Emitido por"}, {"VAL", "Válido até"}}, ;
    "SELECT UNI_CODIGO, CON_CODIGO, USR_LOGIN, strftime('%d/%m/%Y %H:%M', VALIDO_ATE, 'localtime') AS VAL FROM GCT_TOKEN " + ;
    "WHERE USADO = 0 AND VALIDO_ATE > datetime('now') AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('GCT_TOKEN')) + "' " + ;
    "ORDER BY VALIDO_ATE DESC")

/*/{Protheus.doc} GcQUsuarios
    Usuários: super vê todos; síndico vê os síndicos do condomínio da sessão.
    Sem colunas de credencial.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQUsuarios()
    Local cOnde := "" as character

    If GcPerfilDoLogin(GcUsuarioSessao()) != "SUPERADMIN"
        cOnde := " AND U.USR_PERFIL = 'SINDICO' AND EXISTS (SELECT 1 FROM USR_COND C WHERE lower(C.USR_LOGIN) = lower(U.USR_LOGIN) " + ;
            "AND C.D_E_L_E_T_ = ' ' AND C.FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "')"
    EndIf
Return GcConsulta({{"USR_LOGIN", "Login"}, {"USR_PERFIL", "Perfil"}, {"CONDS", "Condomínios"}, {"SIT", "Situação"}}, ;
    "SELECT U.USR_LOGIN, U.USR_PERFIL, " + ;
    "CASE WHEN U.USR_PERFIL = 'SUPERADMIN' THEN 'todos' ELSE IFNULL((SELECT group_concat(C.FILIAL, ', ') FROM USR_COND C " + ;
    "WHERE lower(C.USR_LOGIN) = lower(U.USR_LOGIN) AND C.D_E_L_E_T_ = ' '), '') END AS CONDS, " + ;
    "CASE WHEN IFNULL(U.USR_BLOQ_ATE, '') > datetime('now') THEN 'bloqueado' WHEN U.USR_TROCA = 'S' THEN 'troca de senha pendente' " + ;
    "ELSE 'ativo' END AS SIT FROM USR U WHERE U.D_E_L_E_T_ = ' '" + cOnde + " ORDER BY U.USR_PERFIL, U.USR_LOGIN")

/*/{Protheus.doc} GcQLancamentos
    Lançamentos do exercício.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cExe, character, exercício
    @return array, {colunas, linhas}; 1a coluna R_E_C_N_O_
*/
User Function GcQLancamentos(cExe)
Return GcConsulta({{"R_E_C_N_O_", "Nº"}, {"LAN_DATA", "Data", "data"}, {"LAN_CONTA_DEB", "Débito"}, {"LAN_CONTA_CRED", "Crédito"}, ;
    {"LAN_VALOR", "Valor (R$)", "R$"}, {"LAN_DESCR", "Histórico"}, {"LAN_TIPO", "Origem"}, {"LAN_USUARIO", "Usuário"}}, ;
    "SELECT R_E_C_N_O_, LAN_DATA, LAN_CONTA_DEB, LAN_CONTA_CRED, LAN_VALOR, IFNULL(LAN_DESCR, '') AS LAN_DESCR, LAN_TIPO, " + ;
    "IFNULL(LAN_USUARIO, '') AS LAN_USUARIO FROM LANCAMENTOS WHERE LAN_EXERCICIO = '" + GcSqlLit(cExe) + "' AND D_E_L_E_T_ = ' ' " + ;
    "AND FILIAL = '" + GcSqlLit(FWxFilial('LANCAMENTOS')) + "' ORDER BY LAN_DATA DESC, R_E_C_N_O_ DESC LIMIT 2000")

/*/{Protheus.doc} GcQPlanoContas
    Plano de contas do condomínio.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQPlanoContas()
Return GcConsulta({{"PLA_CODIGO", "Código"}, {"PLA_NOME", "Nome"}, {"PLA_TIPO", "Tipo"}}, ;
    "SELECT PLA_CODIGO, PLA_NOME, PLA_TIPO FROM PLANO_CONTAS WHERE PLA_ATIVO = 1 AND D_E_L_E_T_ = ' ' " + ;
    "AND FILIAL = '" + GcSqlLit(FWxFilial('PLANO_CONTAS')) + "' ORDER BY PLA_CODIGO")

/*/{Protheus.doc} GcQExercicios
    Exercícios contábeis.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQExercicios()
Return GcConsulta({{"EXE_CODIGO", "Exercício"}, {"EXE_INICIO", "Início", "data"}, {"EXE_FIM", "Fim", "data"}, {"SIT", "Situação"}}, ;
    "SELECT EXE_CODIGO, EXE_INICIO, EXE_FIM, CASE WHEN EXE_FECHADO = 1 THEN 'fechado' WHEN EXE_ATIVO = 1 THEN 'ativo' ELSE 'aberto' END AS SIT " + ;
    "FROM EXERCICIO WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('EXERCICIO')) + "' ORDER BY EXE_CODIGO DESC")

/*/{Protheus.doc} GcQBalancete
    Balancete do exercício por conta: débitos, créditos e saldo pela
    natureza da conta (ATIVO e DESPESA: débito - crédito; PASSIVO e
    RECEITA: crédito - débito).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cExe, character, exercício
    @return array, {colunas, linhas}
*/
User Function GcQBalancete(cExe)
    Local cFil := GcSqlLit(FWxFilial('LANCAMENTOS')) as character
    Local cE   := GcSqlLit(cExe) as character
Return GcConsulta({{"PLA_CODIGO", "Conta"}, {"PLA_NOME", "Nome"}, {"PLA_TIPO", "Tipo"}, {"DEB", "Débitos (R$)", "R$"}, ;
    {"CRED", "Créditos (R$)", "R$"}, {"SALDO", "Saldo (R$)", "R$"}}, ;
    "SELECT X.*, CASE WHEN X.PLA_TIPO IN ('ATIVO', 'DESPESA') THEN X.DEB - X.CRED ELSE X.CRED - X.DEB END AS SALDO FROM (" + ;
    "SELECT P.PLA_CODIGO, P.PLA_NOME, P.PLA_TIPO, " + ;
    "IFNULL((SELECT SUM(L.LAN_VALOR) FROM LANCAMENTOS L WHERE L.LAN_CONTA_DEB = P.PLA_CODIGO AND L.LAN_EXERCICIO = '" + cE + "' " + ;
    "AND L.D_E_L_E_T_ = ' ' AND L.FILIAL = '" + cFil + "'), 0) AS DEB, " + ;
    "IFNULL((SELECT SUM(L.LAN_VALOR) FROM LANCAMENTOS L WHERE L.LAN_CONTA_CRED = P.PLA_CODIGO AND L.LAN_EXERCICIO = '" + cE + "' " + ;
    "AND L.D_E_L_E_T_ = ' ' AND L.FILIAL = '" + cFil + "'), 0) AS CRED " + ;
    "FROM PLANO_CONTAS P WHERE P.D_E_L_E_T_ = ' ' AND P.FILIAL = '" + cFil + "') X ORDER BY X.PLA_CODIGO")

/*/{Protheus.doc} GcQAnomalias
    Anomalias registradas pela auditoria.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQAnomalias()
Return GcConsulta({{"ANL_CRIADO_EM", "Data", "data"}, {"ANL_PERIODO", "Período"}, {"ANL_TIPO", "Tipo"}, {"ANL_DESCRICAO", "Descrição"}, ;
    {"ANL_STATUS", "Situação"}}, ;
    "SELECT ANL_CRIADO_EM, ANL_PERIODO, ANL_TIPO, IFNULL(ANL_DESCRICAO, '') AS ANL_DESCRICAO, ANL_STATUS FROM ANOMALIA_LOG " + ;
    "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('ANOMALIA_LOG')) + "' ORDER BY ANL_CRIADO_EM DESC LIMIT 500")

/*/{Protheus.doc} GcQAlertas
    Alertas da auditoria.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQAlertas()
Return GcConsulta({{"ALT_CRIADO_EM", "Data", "data"}, {"ALT_TIPO", "Tipo"}, {"ALT_MENSAGEM", "Mensagem"}, {"VISTO", "Visto"}}, ;
    "SELECT ALT_CRIADO_EM, ALT_TIPO, ALT_MENSAGEM, CASE WHEN ALT_VISTO = 1 THEN 'sim' ELSE 'não' END AS VISTO FROM ALERTA " + ;
    "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('ALERTA')) + "' ORDER BY ALT_CRIADO_EM DESC LIMIT 500")

/*/{Protheus.doc} GcQInadimplencia
    Cobranças atrasadas com os dias de atraso (atualiza a situação antes).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {colunas, linhas}
*/
User Function GcQInadimplencia()
    GcAtualizarInadimplentes()
Return GcConsulta({{"COB_UNIDADE", "Unidade"}, {"CON_NOME", "Condômino"}, {"COB_COMPET", "Competência", "comp"}, {"COB_VALOR", "Valor (R$)", "R$"}, ;
    {"COB_VENCTO", "Vencimento", "data"}, {"DIAS", "Dias de atraso", "number"}}, ;
    "SELECT C.COB_UNIDADE, IFNULL(N.CON_NOME, '') AS CON_NOME, C.COB_COMPET, C.COB_VALOR, C.COB_VENCTO, " + ;
    "CAST(julianday('now') - julianday(C.COB_VENCTO) AS INTEGER) AS DIAS FROM COB C " + ;
    "LEFT JOIN UNI U ON U.UNI_CODIGO = C.COB_UNIDADE AND U.FILIAL = C.FILIAL AND U.D_E_L_E_T_ = ' ' " + ;
    "LEFT JOIN CON N ON N.CON_CODIGO = U.UNI_CONDOMINO AND N.FILIAL = C.FILIAL AND N.D_E_L_E_T_ = ' ' " + ;
    "WHERE C.COB_STATUS = 'atrasado' AND C.D_E_L_E_T_ = ' ' AND C.FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "' ORDER BY C.COB_VENCTO")

/*/{Protheus.doc} GcQDespesasCategoria
    Despesas somadas por categoria (competência vazia = todas).
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cComp, character, AAAA-MM ou ""
    @return array, {colunas, linhas}
*/
User Function GcQDespesasCategoria(cComp)
    Local cF := "" as character

    If !Empty(cComp)
        cF := " AND DES_COMPET = '" + GcSqlLit(cComp) + "'"
    EndIf
Return GcConsulta({{"CATEG", "Categoria"}, {"QTD", "Lançamentos", "number"}, {"TOTAL", "Total (R$)", "R$"}}, ;
    "SELECT COALESCE(NULLIF(DES_CATEG, ''), '(sem categoria)') AS CATEG, COUNT(*) AS QTD, SUM(DES_VALOR) AS TOTAL FROM DES " + ;
    "WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'" + cF + " GROUP BY 1 ORDER BY TOTAL DESC")

/*/{Protheus.doc} GcResultadoMensal
    Resultado da competência: cobranças recebidas, despesas e saldo.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cComp, character, AAAA-MM
    @return array, {nRecebido, nDespesas, nSaldo, nEmAberto}
*/
User Function GcResultadoMensal(cComp)
    Local aC := TCSqlQuery("SELECT IFNULL(SUM(CASE WHEN COB_STATUS = 'pago' THEN COB_VALOR END), 0) AS REC, " + ;
        "IFNULL(SUM(CASE WHEN COB_STATUS <> 'pago' THEN COB_VALOR END), 0) AS ABE FROM COB WHERE COB_COMPET = '" + GcSqlLit(cComp) + "' " + ;
        "AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'") as array
    Local aD := TCSqlQuery("SELECT IFNULL(SUM(DES_VALOR), 0) AS DES FROM DES WHERE DES_COMPET = '" + GcSqlLit(cComp) + "' " + ;
        "AND D_E_L_E_T_ = ' ' AND FILIAL = '" + GcSqlLit(FWxFilial('DES')) + "'") as array
    Local nRec := Round(Val(aC[1]:REC), 2) as numeric
    Local nDes := Round(Val(aD[1]:DES), 2) as numeric
Return {nRec, nDes, Round(nRec - nDes, 2), Round(Val(aC[1]:ABE), 2)}

/*/{Protheus.doc} GcIndicadores
    Indicadores do Início: unidades, soma das frações (%), total em aberto,
    total atrasado (e quantas cobranças), despesas da competência atual.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return array, {nUnidades, nFracaoPerc, nAberto, nAtrasado, nQtdAtrasadas, nDespMes}
*/
User Function GcIndicadores()
    Local cFil  := GcSqlLit(FWxFilial('COB')) as character
    Local cComp := Left(DToS(Date()), 4) + "-" + SubStr(DToS(Date()), 5, 2) as character
    Local aU    := {} as array
    Local aC    := {} as array
    Local aD    := {} as array

    GcAtualizarInadimplentes()
    aU := TCSqlQuery("SELECT COUNT(*) AS Q, IFNULL(SUM(UNI_FRACAO), 0) AS F FROM UNI WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")
    aC := TCSqlQuery("SELECT IFNULL(SUM(CASE WHEN COB_STATUS <> 'pago' THEN COB_VALOR END), 0) AS ABE, " + ;
        "IFNULL(SUM(CASE WHEN COB_STATUS = 'atrasado' THEN COB_VALOR END), 0) AS ATR, " + ;
        "SUM(CASE WHEN COB_STATUS = 'atrasado' THEN 1 ELSE 0 END) AS QATR FROM COB WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")
    aD := TCSqlQuery("SELECT IFNULL(SUM(DES_VALOR), 0) AS D FROM DES WHERE DES_COMPET = '" + cComp + "' AND D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + "'")
Return {Val(aU[1]:Q), Round(Val(aU[1]:F) * 100, 4), Round(Val(aC[1]:ABE), 2), Round(Val(aC[1]:ATR), 2), Val(aC[1]:QATR), Round(Val(aD[1]:D), 2)}
