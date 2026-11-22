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
        "JOIN UNI ON UNI.UNI_CODIGO = COB.COB_UNIDADE AND UNI.D_E_L_E_T_ = ' ' AND UNI.FILIAL = '" + GcSqlLit(FWxFilial('UNI')) + "' " + ;
        "JOIN CON ON CON.CON_CODIGO = UNI.UNI_CONDOMINO AND CON.D_E_L_E_T_ = ' ' AND CON.FILIAL = '" + GcSqlLit(FWxFilial('CON')) + "' " + ;
        "WHERE COB.COB_COMPET = '" + GcSqlLit(cCompetencia) + "' AND COB.COB_STATUS <> 'pago' AND COB.D_E_L_E_T_ = ' ' AND COB.FILIAL = '" + GcSqlLit(FWxFilial('COB')) + "'")

    Local nEnviados := 0
    Local i
    For i := 1 To Len(aDest)
        If GcEmailValido(aDest[i]:EMAIL)
            Local cCorpo := GcMalaCorpo(aDest[i]:NOME, aDest[i]:UNIDADE, cCompetencia, ;
                Val(aDest[i]:VALOR), aDest[i]:VENCTO, aDest[i]:STATUS)
            Begin Sequence
                Local oMail := TMailMessage():New()
                oMail:SetServer(cHost, cPort)
                If !Empty(cUser)
                    oMail:SetAuth(cUser, cPass)
                EndIf
                oMail:SetFrom(cFrom)
                oMail:AddTo(AllTrim(aDest[i]:EMAIL))
                // Sem CR/LF no assunto: o texto vem de cadastro e iria para o cabeçalho
                oMail:SetSubject(StrTran(StrTran("GesCon — Cobrança " + cCompetencia + " — Unidade " + ;
                    AllTrim(aDest[i]:UNIDADE), Chr(13), " "), Chr(10), " "))
                oMail:SetBody(cCorpo)
                If oMail:Send()
                    nEnviados++
                EndIf
            Recover
                ConOut("GcMalaDireta: falha ao enviar pra " + aDest[i]:EMAIL + " (unidade " + aDest[i]:UNIDADE + ")")
            End Sequence
        ElseIf !Empty(aDest[i]:EMAIL)
            ConOut("GcMalaDireta: e-mail inválido ignorado (unidade " + aDest[i]:UNIDADE + ")")
        EndIf
    Next
Return nEnviados

/*/{Protheus.doc} GcEmailValido
    Validação simples de endereço antes de ir para o cabeçalho da
    mensagem: sem espaço, CR, LF, vírgula, ponto e vírgula, aspas ou
    sinais < >; exatamente um "@"; domínio com ponto e sem ponto nas
    pontas. Não pretende cobrir a RFC 5322 inteira, só barrar o que quebra
    ou injeta cabeçalho.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cEmail, character, endereço
    @return logical, .T. se aceitável
*/
User Function GcEmailValido(cEmail)
    Local cEnd    := "" as character
    Local cDom    := "" as character
    Local nArroba := 0 as numeric
    Local nI      := 0 as numeric

    If ValType(cEmail) != "C"
        Return .F.
    EndIf
    cEnd := AllTrim(cEmail)
    If Empty(cEnd) .Or. Len(cEnd) > 254
        Return .F.
    EndIf
    For nI := 1 To Len(cEnd)
        If SubStr(cEnd, nI, 1) $ ' ,;<>"' + Chr(13) + Chr(10) + Chr(9) .Or. Asc(SubStr(cEnd, nI, 1)) < 32
            Return .F.
        EndIf
    Next nI
    nArroba := At("@", cEnd)
    If nArroba < 2 .Or. At("@", SubStr(cEnd, nArroba + 1)) > 0
        Return .F.
    EndIf
    cDom := SubStr(cEnd, nArroba + 1)
Return At(".", cDom) > 1 .And. Right(cDom, 1) != "." .And. !(".." $ cDom)

/*/{Protheus.doc} GcMalaCorpo
    Texto da mensagem de cobrança: valor em reais (R$ 1.234,56) e
    vencimento em DD/MM/AAAA. Antes saíam crus ("350.5", "2026-12-10").
    @type User Function
    @author GesCon
    @since 2026-11-21
    @param cNome, character, nome do condômino
    @param cUnidade, character, unidade
    @param cCompetencia, character, AAAA-MM
    @param nValor, numeric, valor
    @param cVencto, character, vencimento AAAA-MM-DD
    @param cStatus, character, situação
    @return character, corpo da mensagem
*/
User Function GcMalaCorpo(cNome, cUnidade, cCompetencia, nValor, cVencto, cStatus)
    Local cVenc := AllTrim(cVencto) as character
    Local cComp := AllTrim(cCompetencia) as character

    If Len(cVenc) == 10 .And. SubStr(cVenc, 5, 1) == "-"
        cVenc := SubStr(cVenc, 9, 2) + "/" + SubStr(cVenc, 6, 2) + "/" + Left(cVenc, 4)
    EndIf
    If Len(cComp) == 7 .And. SubStr(cComp, 5, 1) == "-"
        cComp := Right(cComp, 2) + "/" + Left(cComp, 4)
    EndIf
Return "Olá " + AllTrim(cNome) + "," + Chr(10) + Chr(10) + ;
    "Referente à unidade " + AllTrim(cUnidade) + ", competência " + cComp + ":" + Chr(10) + ;
    "Valor: R$ " + AllTrim(Transform(nValor, "@E 999,999,999.99")) + Chr(10) + ;
    "Vencimento: " + cVenc + Chr(10) + ;
    "Situação: " + Upper(Left(AllTrim(cStatus), 1)) + Lower(SubStr(AllTrim(cStatus), 2))
