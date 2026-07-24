// src/db.prw — camada de acesso SQL do GesCon. Toda query direta às
// tabelas UNI/CON/DES/COB/USR passa por aqui, nunca espalhada pelas telas.
#include "totvs.ch"

/*/{Protheus.doc} GcSqlLit
    Escapa aspas simples — todo valor de texto interpolado numa query via
    TCSqlExec/TCSqlQuery precisa passar por aqui (sem parâmetros bind na
    API atual, escapar é a única defesa contra literal quebrado).
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cValor, character, valor a escapar (aceita Nil)
    @return cRet, character, valor com aspas simples duplicadas
*/
User Function GcSqlLit(cValor)
    Local cRet := cValor
    If cRet == Nil
        cRet := ""
    EndIf
Return StrTran(cRet, "'", "''")
