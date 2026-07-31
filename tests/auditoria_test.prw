// tests/auditoria_test.prw — Testes das tabelas de auditoria e anomalias
// Verifica cria??o e exist?ncia das tabelas ANOMALIA_LOG, ALERTA e DASHBOARD_CACHE
#include "totvs.ch"
#include "../src/db.prw"

/*/{Protheus.doc} TestAuditoriaTablesExist
    Verifica que todas as 3 tabelas de auditoria existem no banco de dados.
    Consulta sqlite_master para confirmar a exist?ncia de:
    - ANOMALIA_LOG
    - ALERTA
    - DASHBOARD_CACHE
    @type Function
    @author GesCon
    @since 2026-07-30
    @return lOk, logical, .T. se todas as tabelas existem, .F. caso contr?rio
*/
User Function TestAuditoriaTablesExist()
    Local lOk := .T.
    Local aAnomalia := {}
    Local aAlerta := {}
    Local aDashboard := {}
    Local cMsg := ""

    // Verifica exist?ncia de ANOMALIA_LOG
    aAnomalia := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ANOMALIA_LOG'")
    If Len(aAnomalia) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela ANOMALIA_LOG n?o encontrada" + CRLF
    Else
        ConOut("OK: Tabela ANOMALIA_LOG existe")
    EndIf

    // Verifica exist?ncia de ALERTA
    aAlerta := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ALERTA'")
    If Len(aAlerta) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela ALERTA n?o encontrada" + CRLF
    Else
        ConOut("OK: Tabela ALERTA existe")
    EndIf

    // Verifica exist?ncia de DASHBOARD_CACHE
    aDashboard := TCSqlQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='DASHBOARD_CACHE'")
    If Len(aDashboard) == 0
        lOk := .F.
        cMsg += "ERRO: Tabela DASHBOARD_CACHE n?o encontrada" + CRLF
    Else
        ConOut("OK: Tabela DASHBOARD_CACHE existe")
    EndIf

    // Log resultado
    If lOk
        ConOut("SUCESSO: Todas as 3 tabelas de auditoria foram criadas com sucesso")
    Else
        ConOut(cMsg)
    EndIf

Return lOk
