/*/{Protheus.doc} GcMalaDireta
    Mala direta: gera e envia (via TMailMessage) uma mensagem personalizada
    por condômino, cobrindo as cobranças não pagas de uma competência.
    Configuração SMTP via variáveis de ambiente — GetMV() é um stub no
    AdvPP (sempre retorna o valor padrão passado, nunca lê configuração
    real; confirmado em teste direto), então GetEnv() é o único mecanismo
    real de configuração sem segredo hardcoded disponível hoje.
    @type Function
    @author GesCon
    @since 2026-07-24
    @param cCompetencia, character, competência "YYYY-MM" a cobrir
    @return nEnviados, numeric, quantidade de e-mails enviados com sucesso
*/
#include "totvs.ch"

User Function GcMalaDireta(cCompetencia)
    Local cHost := GetEnv("GESCON_SMTP_HOST", "")
    If Empty(cHost)
        ConOut("GcMalaDireta: GESCON_SMTP_HOST não configurado, nada enviado")
        Return 0
    EndIf
    Local cPort := GetEnv("GESCON_SMTP_PORT", "587")
    Local cUser := GetEnv("GESCON_SMTP_USER", "")
    Local cPass := GetEnv("GESCON_SMTP_PASS", "")
    Local cFrom := GetEnv("GESCON_SMTP_FROM", "gescon@localhost")

    Local aDest := TCSqlQuery("SELECT COB.COB_UNIDADE AS UNIDADE, COB.COB_VALOR AS VALOR, " + ;
        "COB.COB_VENCTO AS VENCTO, COB.COB_STATUS AS STATUS, CON.CON_NOME AS NOME, CON.CON_EMAIL AS EMAIL " + ;
        "FROM COB " + ;
        "JOIN UNI ON UNI.UNI_CODIGO = COB.COB_UNIDADE AND UNI.D_E_L_E_T_ = ' ' " + ;
        "JOIN CON ON CON.CON_CODIGO = UNI.UNI_CONDOMINO AND CON.D_E_L_E_T_ = ' ' " + ;
        "WHERE COB.COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND COB.COB_STATUS <> 'pago' AND COB.D_E_L_E_T_ = ' '")

    Local nEnviados := 0
    Local i
    For i := 1 To Len(aDest)
        If !Empty(aDest[i]:EMAIL)
            Local cCorpo := "Olá " + aDest[i]:NOME + "," + Chr(10) + Chr(10) + ;
                "Referente à unidade " + aDest[i]:UNIDADE + ", competência " + cCompetencia + ":" + Chr(10) + ;
                "Valor: " + aDest[i]:VALOR + Chr(10) + ;
                "Vencimento: " + aDest[i]:VENCTO + Chr(10) + ;
                "Situação: " + aDest[i]:STATUS
            Begin Sequence
                Local oMail := TMailMessage():New()
                oMail:SetServer(cHost, cPort)
                If !Empty(cUser)
                    oMail:SetAuth(cUser, cPass)
                EndIf
                oMail:SetFrom(cFrom)
                oMail:AddTo(aDest[i]:EMAIL)
                oMail:SetSubject("GesCon — Cobrança " + cCompetencia + " — Unidade " + aDest[i]:UNIDADE)
                oMail:SetBody(cCorpo)
                If oMail:Send()
                    nEnviados++
                EndIf
            Recover
                ConOut("GcMalaDireta: falha ao enviar pra " + aDest[i]:EMAIL + " (unidade " + aDest[i]:UNIDADE + ")")
            End Sequence
        EndIf
    Next
Return nEnviados
