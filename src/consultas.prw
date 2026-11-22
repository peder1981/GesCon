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
