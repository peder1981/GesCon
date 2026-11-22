// src/nfse.prw -- NFS-e de padrão nacional das cobranças do condomínio.
//
// Obrigação: Decreto 12.955/2026, art. 115, VI, "d" (o condomínio edilício
// emite documento fiscal mesmo sem ser contribuinte); início em 01/01/2027
// (Ato Conjunto RFB/CGIBS 4/2026, alterado pelo 7/2026).
// Leiaute: DPS v1.01 (XSD da produção restrita de 20/10/2026) com o grupo
// IBSCBS/condominios da NT SE/CGNFS-e 009 v1.01 (item 2.15), que o XSD
// publicado ainda não traz; posição do grupo conforme o Anexo VI v1.04.01
// (depois de bensMoveis, antes de valores).
//   - cTribNac 990501 "Operações Condominiais"; NBS 1.1001.90.00 e cIndOp
//     020201 (local do imóvel) pela correlação oficial (Anexo VIII v1.02.00).
//   - Não optante: CST 410 / cClassTrib 410012 ("fornecimento de condomínio
//     edilício não optante pelo regime regular", tabela cClassTrib do portal
//     DF-e, uso em NFS-e permitido). Optante: CST 200 / cClassTrib 200046
//     (Anexo VIII). A Sefin calcula o IBS e a CBS; a DPS não leva alíquota.
//   - ISSQN: não incide (tribISSQN 4).
// Envio: POST {base}/nfse com {"dpsXmlGZipB64": base64(gzip(DPS assinada))},
// TLS com o certificado A1 do condomínio.
#include "totvs.ch"

#define GC_NFSE_NS     "http://www.sped.fazenda.gov.br/nfse"
#define GC_DSIG_NS     "http://www.w3.org/2000/09/xmldsig#"
#define GC_C14N        "http://www.w3.org/TR/2001/REC-xml-c14n-20010315"

/*/{Protheus.doc} GcNfseDps
    Monta a DPS (sem assinatura) de uma cobrança do condomínio aberto.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param nCob, numeric, R_E_C_N_O_ da cobrança
    @param cSerie, character, série da DPS
    @param nNum, numeric, número da DPS
    @param cDhEmi, character, data e hora de emissão AAAA-MM-DDThh:mm:ss-03:00
    @return array, {cId, cXml, cErro}: cErro preenchido quando não dá para emitir
*/
User Function GcNfseDps(nCob, cSerie, nNum, cDhEmi)
    Local aCfg   := GcFiscalCfg() as array
    Local cFil   := GcSqlLit(FWxFilial('COB')) as character
    Local aC     := {} as array
    Local aCond  := {} as array
    Local cCnpj  := "" as character
    Local cDoc   := "" as character
    Local cId    := "" as character
    Local cX     := "" as character
    Local cComp  := "" as character
    Local cVenc  := "" as character
    Local cRegime := "" as character
    Local nValor := 0 as numeric

    aC := TCSqlQuery("SELECT C.COB_UNIDADE, C.COB_COMPET, C.COB_VALOR, IFNULL(C.COB_VENCTO, '') AS COB_VENCTO, " + ;
        "IFNULL(N.CON_NOME, '') AS CON_NOME, IFNULL(N.CON_CPF, '') AS CON_CPF FROM COB C " + ;
        "LEFT JOIN UNI U ON U.UNI_CODIGO = C.COB_UNIDADE AND U.FILIAL = C.FILIAL AND U.D_E_L_E_T_ = ' ' " + ;
        "LEFT JOIN CON N ON N.CON_CODIGO = U.UNI_CONDOMINO AND N.FILIAL = C.FILIAL AND N.D_E_L_E_T_ = ' ' " + ;
        "WHERE C.R_E_C_N_O_ = " + cValToChar(Int(nCob)) + " AND C.FILIAL = '" + cFil + "' AND C.D_E_L_E_T_ = ' '")
    If Len(aC) == 0
        Return {"", "", "Cobrança não encontrada neste condomínio."}
    EndIf
    // check-filial: global -- COND é o cadastro de condomínios; a linha é a da própria filial (COND_FILIAL).
    aCond := TCSqlQuery("SELECT IFNULL(COND_CNPJ, '') AS COND_CNPJ FROM COND WHERE D_E_L_E_T_ = ' ' AND COND_FILIAL = '" + ;
        GcSqlLit(FWxFilial('COB')) + "'")
    If Len(aCond) > 0
        cCnpj := GcDocumentoNormal(aCond[1]:COND_CNPJ)
    EndIf
    If Len(cCnpj) != 14 .Or. !GcDocumentoValido(cCnpj)
        Return {"", "", "Cadastre o CNPJ do condomínio (Condomínios) antes de emitir a NFS-e."}
    EndIf
    If Len(aCfg[4]) != 7
        Return {"", "", "Informe o município (código IBGE) nos dados fiscais antes de emitir a NFS-e."}
    EndIf
    cDoc := GcDocumentoNormal(aC[1]:CON_CPF)
    If Empty(aC[1]:CON_NOME) .Or. !GcDocumentoValido(cDoc)
        Return {"", "", "A unidade " + AllTrim(aC[1]:COB_UNIDADE) + " precisa de condômino com CPF ou CNPJ válido para a NFS-e."}
    EndIf
    nValor := Round(Val(cValToChar(aC[1]:COB_VALOR)), 2)
    If nValor <= 0
        Return {"", "", "Cobrança sem valor."}
    EndIf
    cComp := AllTrim(aC[1]:COB_COMPET)
    cVenc := GcIsoData(aC[1]:COB_VENCTO)
    If Empty(cVenc)
        Return {"", "", "Cobrança sem vencimento válido."}
    EndIf
    If GcRegimeEm(SToD(StrTran(cComp, "-", "") + "01")) == "R"
        cRegime := "200|200046"
    Else
        cRegime := "410|410012"
    EndIf

    cId := "DPS" + aCfg[4] + "2" + cCnpj + StrZero(Val(cSerie), 5) + StrZero(nNum, 15)
    cX := '<DPS xmlns="' + GC_NFSE_NS + '" versao="1.01"><infDPS Id="' + cId + '">'
    cX += GcTag("tpAmb", aCfg[5]) + GcTag("dhEmi", cDhEmi) + GcTag("verAplic", "GesCon") + ;
        GcTag("serie", cValToChar(Val(cSerie))) + GcTag("nDPS", cValToChar(nNum)) + GcTag("dCompet", cComp + "-01") + ;
        GcTag("tpEmit", "1") + GcTag("finNFSe", "0") + GcTag("cLocEmi", aCfg[4])
    cX += "<prest>" + GcTag("CNPJ", cCnpj) + "<regTrib>" + GcTag("opSimpNac", "1") + GcTag("regEspTrib", "0") + "</regTrib></prest>"
    cX += "<toma>"
    If Len(cDoc) == 11
        cX += GcTag("CPF", cDoc)
    Else
        cX += GcTag("CNPJ", cDoc)
    EndIf
    cX += GcTag("xNome", Left(AllTrim(aC[1]:CON_NOME), 300)) + "</toma>"
    cX += "<serv><locPrest>" + GcTag("cLocPrestacao", aCfg[4]) + "</locPrest><cServ>" + GcTag("cTribNac", "990501") + ;
        GcTag("cNBS", "110019000") + GcTag("xDescServ", "Taxa condominial da unidade " + AllTrim(aC[1]:COB_UNIDADE) + ;
        ", competência " + Right(cComp, 2) + "/" + Left(cComp, 4)) + "</cServ></serv>"
    cX += "<valores><vServPrest>" + GcTag("vServ", GcDec2(nValor)) + "</vServPrest><trib><tribMun>" + ;
        GcTag("tribISSQN", "4") + GcTag("tpRetISSQN", "1") + "</tribMun><totTrib>" + GcTag("indTotTrib", "0") + ;
        "</totTrib></trib></valores>"
    cX += "<IBSCBS>" + GcTag("cIndOp", "020201") + GcTag("indDest", "0") + "<imovel>" + GcTag("cMun", aCfg[4]) + "</imovel>" + ;
        "<condominios>" + GcTag("dVencOrig", cVenc) + "<gCobranca>" + GcTag("tpCobranca", "01") + GcTag("vCobranca", GcDec2(nValor)) + ;
        "</gCobranca></condominios><valores><trib>" + GcTag("CST", Left(cRegime, 3)) + GcTag("cClassTrib", Right(cRegime, 6)) + ;
        "</trib></valores></IBSCBS>"
    cX += "</infDPS></DPS>"
Return {cId, cX, ""}

/*/{Protheus.doc} GcNfseAssinar
    Assina a DPS (XMLDSig envelopado, C14N 1.0, RSA-SHA256, digest SHA-256),
    com o certificado no KeyInfo.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cXml, character, DPS sem assinatura (de GcNfseDps)
    @param cId, character, Id do infDPS
    @param cChavePem, character, chave privada PEM (conteúdo)
    @param cCertPem, character, certificado PEM (conteúdo)
    @return character, DPS assinada ("" se a assinatura falhar)
*/
User Function GcNfseAssinar(cXml, cId, cChavePem, cCertPem)
    Local nIni     := At("<infDPS ", cXml) as numeric
    Local nFim     := At("</infDPS>", cXml) as numeric
    Local cInf     := "" as character
    Local cDigest  := "" as character
    Local cSigned  := "" as character
    Local cAss     := "" as character
    Local cErro    := "" as character
    Local cCert    := "" as character

    If nIni == 0 .Or. nFim == 0
        Return ""
    EndIf
    cInf := SubStr(cXml, nIni, nFim + Len("</infDPS>") - nIni)
    // O infDPS herda o namespace padrão do DPS: na forma canônica ele aparece
    // declarado no próprio elemento.
    cDigest := Encode64(SHA256(XmlC14N(StrTran(cInf, "<infDPS ", '<infDPS xmlns="' + GC_NFSE_NS + '" ', 1, 1)), 1))
    cSigned := '<SignedInfo xmlns="' + GC_DSIG_NS + '"><CanonicalizationMethod Algorithm="' + GC_C14N + '"></CanonicalizationMethod>' + ;
        '<SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"></SignatureMethod>' + ;
        '<Reference URI="#' + cId + '"><Transforms><Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"></Transform>' + ;
        '<Transform Algorithm="' + GC_C14N + '"></Transform></Transforms>' + ;
        '<DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"></DigestMethod>' + ;
        '<DigestValue>' + cDigest + '</DigestValue></Reference></SignedInfo>'
    cAss := PrivSignRSA(cChavePem, XmlC14N(cSigned), 5, "", @cErro)
    If ValType(cAss) != "C" .Or. Empty(cAss)
        Return ""
    EndIf
    cCert := StrTran(StrTran(StrTran(StrTran(cCertPem, "-----BEGIN CERTIFICATE-----", ""), "-----END CERTIFICATE-----", ""), Chr(13), ""), Chr(10), "")
    If "-----" $ cCert
        // Mais de um certificado no PEM: fica só o primeiro.
        cCert := Left(cCert, At("-----", cCert) - 1)
    EndIf
Return StrTran(cXml, "</infDPS></DPS>", '</infDPS><Signature xmlns="' + GC_DSIG_NS + '">' + ;
    StrTran(cSigned, ' xmlns="' + GC_DSIG_NS + '"', "", 1, 1) + "<SignatureValue>" + Encode64(cAss) + "</SignatureValue>" + ;
    "<KeyInfo><X509Data><X509Certificate>" + AllTrim(cCert) + "</X509Certificate></X509Data></KeyInfo></Signature></DPS>")

/*/{Protheus.doc} GcNfseGerar
    Gera e assina a DPS de uma cobrança e grava em NFS (situação "assinada").
    Reaproveita série e número de uma DPS anterior da mesma cobrança que não
    virou NFS-e (rejeitada ou não enviada); senão, reserva o próximo número.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param nCob, numeric, cobrança
    @param cSenha, character, senha do certificado A1
    @return array, {cMotivo, nRecnoNFS}: cMotivo "" quando gerou
*/
User Function GcNfseGerar(nCob, cSenha)
    Local aCfg   := GcFiscalCfg() as array
    Local cFil   := GcSqlLit(FWxFilial('NFS')) as character
    Local aAnt   := {} as array
    Local aNum   := {} as array
    Local aDps   := {} as array
    Local aPem   := {} as array
    Local cSerie := "" as character
    Local nNum   := 0 as numeric
    Local nRec   := 0 as numeric
    Local cDh    := GcAgoraBrasilia() as character
    Local cAss   := "" as character

    If Empty(aCfg[8])
        Return {"Informe o certificado A1 (.pfx) nos dados fiscais.", 0}
    EndIf
    aAnt := TCSqlQuery("SELECT R_E_C_N_O_, NFS_SERIE, NFS_NDPS, NFS_STATUS FROM NFS WHERE D_E_L_E_T_ = ' ' AND FILIAL = '" + cFil + ;
        "' AND NFS_COB = " + cValToChar(Int(nCob)) + " ORDER BY R_E_C_N_O_ DESC")
    If Len(aAnt) > 0 .And. AllTrim(aAnt[1]:NFS_STATUS) == "autorizada"
        Return {"Esta cobrança já tem NFS-e autorizada.", 0}
    EndIf
    // Certificado antes do número: senha errada não gasta numeração.
    aPem := GcCertificadoPem(aCfg[8], cSenha)
    If !Empty(aPem[3])
        Return {aPem[3], 0}
    EndIf
    If Len(aAnt) > 0
        nRec   := Val(cValToChar(aAnt[1]:R_E_C_N_O_))
        cSerie := AllTrim(aAnt[1]:NFS_SERIE)
        nNum   := Val(cValToChar(aAnt[1]:NFS_NDPS))
    Else
        // Confere a DPS antes de gastar número.
        aDps := GcNfseDps(nCob, aCfg[6], 1, cDh)
        If !Empty(aDps[3])
            Return {aDps[3], 0}
        EndIf
        TCSqlExec("INSERT OR IGNORE INTO FIS (FILIAL) VALUES ('" + cFil + "')")
        aNum := TCSqlQuery("UPDATE FIS SET FIS_NDPS = FIS_NDPS + 1 WHERE FILIAL = '" + cFil + "' RETURNING FIS_NDPS, FIS_SERIE")
        If Len(aNum) == 0
            Return {"Não foi possível numerar a DPS: " + TCSqlError(), 0}
        EndIf
        nNum   := Val(cValToChar(aNum[1]:FIS_NDPS))
        cSerie := AllTrim(aNum[1]:FIS_SERIE)
    EndIf
    aDps := GcNfseDps(nCob, cSerie, nNum, cDh)
    If !Empty(aDps[3])
        Return {aDps[3], 0}
    EndIf
    cAss := GcNfseAssinar(aDps[2], aDps[1], aPem[1], aPem[2])
    aPem := {}
    If Empty(cAss)
        Return {"Não foi possível assinar a DPS com o certificado informado.", 0}
    EndIf
    If nRec == 0
        If !TCSqlExec("INSERT INTO NFS (FILIAL, NFS_COB, NFS_SERIE, NFS_NDPS, NFS_ID, NFS_STATUS, NFS_XML, NFS_DHEMI) VALUES ('" + ;
                cFil + "', " + cValToChar(Int(nCob)) + ", '" + GcSqlLit(cSerie) + "', " + cValToChar(nNum) + ", '" + aDps[1] + ;
                "', 'assinada', '" + GcSqlLit(cAss) + "', '" + cDh + "')")
            Return {"Não foi possível gravar a DPS: " + TCSqlError(), 0}
        EndIf
        nRec := Val(cValToChar(TCSqlQuery("SELECT R_E_C_N_O_ FROM NFS WHERE FILIAL = '" + cFil + "' AND NFS_ID = '" + aDps[1] + ;
            "' ORDER BY R_E_C_N_O_ DESC LIMIT 1")[1]:R_E_C_N_O_))
    ElseIf !TCSqlExec("UPDATE NFS SET NFS_STATUS = 'assinada', NFS_XML = '" + GcSqlLit(cAss) + "', NFS_DHEMI = '" + cDh + ;
            "', NFS_ID = '" + aDps[1] + "' WHERE R_E_C_N_O_ = " + cValToChar(nRec) + " AND FILIAL = '" + cFil + "'")
        Return {"Não foi possível gravar a DPS: " + TCSqlError(), 0}
    EndIf
Return {"", nRec}

/*/{Protheus.doc} GcNfseEmitir
    Gera, assina e envia a DPS de uma cobrança à Sefin Nacional; grava a
    chave de acesso (autorizada) ou o motivo (rejeitada).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param nCob, numeric, cobrança
    @param cSenha, character, senha do certificado A1
    @return character, "" se a NFS-e foi autorizada, ou o motivo
*/
User Function GcNfseEmitir(nCob, cSenha)
    Local aCfg   := GcFiscalCfg() as array
    Local cFil   := GcSqlLit(FWxFilial('NFS')) as character
    Local aG     := GcNfseGerar(nCob, cSenha) as array
    Local aX     := {} as array
    Local nSt    := 0 as numeric
    Local cBody  := "" as character
    Local cChave := "" as character
    Local cMsg   := "" as character
    Local cUrl   := "" as character

    If !Empty(aG[1])
        Return aG[1]
    EndIf
    aX := TCSqlQuery("SELECT NFS_XML FROM NFS WHERE R_E_C_N_O_ = " + cValToChar(aG[2]) + " AND FILIAL = '" + cFil + "'")
    cUrl := GcNfseUrlBase(aCfg[5]) + "/nfse"
    nSt := FWHTTPPost(cUrl, '{"dpsXmlGZipB64":"' + Encode64(GzStrComp(aX[1]:NFS_XML)) + '"}', "application/json", aCfg[8], cSenha)
    cBody := FWHTTPBody()
    If nSt == 0
        cMsg := "Sem resposta da Sefin Nacional (" + FWHTTPError() + "). A DPS ficou gravada; tente de novo."
        TCSqlExec("UPDATE NFS SET NFS_RETORNO = '" + GcSqlLit(cMsg) + "' WHERE R_E_C_N_O_ = " + cValToChar(aG[2]) + " AND FILIAL = '" + cFil + "'")
        Return cMsg
    EndIf
    cChave := GcJsonTexto(cBody, "chaveAcesso")
    If (nSt == 200 .Or. nSt == 201) .And. !Empty(cChave)
        TCSqlExec("UPDATE NFS SET NFS_STATUS = 'autorizada', NFS_CHAVE = '" + GcSqlLit(cChave) + "', NFS_RETORNO = '" + ;
            GcSqlLit(Left(cBody, 4000)) + "' WHERE R_E_C_N_O_ = " + cValToChar(aG[2]) + " AND FILIAL = '" + cFil + "'")
        Return ""
    EndIf
    cMsg := GcNfseErros(cBody)
    If Empty(cMsg)
        cMsg := "HTTP " + cValToChar(nSt) + ": " + Left(cBody, 300)
    EndIf
    TCSqlExec("UPDATE NFS SET NFS_STATUS = 'rejeitada', NFS_RETORNO = '" + GcSqlLit(Left(cMsg, 4000)) + "' WHERE R_E_C_N_O_ = " + ;
        cValToChar(aG[2]) + " AND FILIAL = '" + cFil + "'")
Return "NFS-e rejeitada: " + cMsg

/*/{Protheus.doc} GcNfseUrlBase
    Endereço da API Sefin Nacional do ambiente. GESCON_NFSE_URL substitui
    (testes contra um servidor local).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cAmb, character, "1" produção | "2" produção restrita
    @return character, URL base sem barra final
*/
User Function GcNfseUrlBase(cAmb)
    Local cEnv := AllTrim(GetEnv("GESCON_NFSE_URL")) as character

    If !Empty(cEnv)
        Return cEnv
    EndIf
    If cAmb == "1"
        Return "https://sefin.nfse.gov.br/SefinNacional"
    EndIf
Return "https://sefin.producaorestrita.nfse.gov.br/SefinNacional"

/*/{Protheus.doc} GcCertificadoPem
    Extrai chave e certificado (PEM) do A1 para a memória, apagando os
    arquivos temporários (0600) na hora.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cPfx, character, caminho do .pfx
    @param cSenha, character, senha
    @return array, {cChavePem, cCertPem, cErro}
*/
User Function GcCertificadoPem(cPfx, cSenha)
    Local cBase := GetTempPath() + "/gescon-" + UUIDRandom() as character
    Local cErr  := "" as character
    Local lKey  := .F. as logical
    Local lCrt  := .F. as logical
    Local cKey  := "" as character
    Local cCrt  := "" as character

    lKey := PFXKey2PEM(cPfx, cBase + ".key", @cErr, cSenha)
    lCrt := PFXCert2PEM(cPfx, cBase + ".crt", @cErr, cSenha)
    If lKey
        cKey := MemoRead(cBase + ".key")
    EndIf
    If lCrt
        cCrt := MemoRead(cBase + ".crt")
    EndIf
    FErase(cBase + ".key")
    FErase(cBase + ".crt")
    If Empty(cKey) .Or. Empty(cCrt)
        Return {"", "", "Não foi possível abrir o certificado A1: confira o arquivo e a senha. Arquivo exportado com " + ;
            "cifra AES (OpenSSL 3) precisa ser reexportado com 3DES (openssl pkcs12 -export -legacy)."}
    EndIf
Return {cKey, cCrt, ""}

/*/{Protheus.doc} GcNfseErros
    Mensagens de erro da resposta da Sefin ({"erros": [{"Codigo", "Descricao"}]}).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cBody, character, corpo JSON
    @return character, "código - descrição; ..." ("" se não vier no formato)
*/
User Function GcNfseErros(cBody)
    Local oJ   := JsonObject():New() as object
    Local aE   := {} as array
    Local cRet := "" as character
    Local nI   := 0 as numeric
    Local cCod := "" as character
    Local cDes := "" as character

    If ValType(oJ:FromJson(cBody)) == "C"
        Return ""
    EndIf
    aE := oJ["erros"]
    If ValType(aE) != "A"
        aE := oJ["Erros"]
    EndIf
    If ValType(aE) != "A"
        Return ""
    EndIf
    For nI := 1 To Len(aE)
        If ValType(aE[nI]) != "J" .And. ValType(aE[nI]) != "O"
            Loop
        EndIf
        cCod := GcJsonCampo(aE[nI], {"Codigo", "codigo"})
        cDes := GcJsonCampo(aE[nI], {"Descricao", "descricao", "Complemento"})
        If !Empty(cRet)
            cRet += "; "
        EndIf
        cRet += AllTrim(cCod + " " + cDes)
    Next
Return cRet

// Primeiro campo presente (texto) de um objeto JSON.
Static Function GcJsonCampo(oJ, aNomes)
    Local nI := 0 as numeric

    For nI := 1 To Len(aNomes)
        If ValType(oJ[aNomes[nI]]) == "C"
            Return oJ[aNomes[nI]]
        EndIf
    Next
Return ""

/*/{Protheus.doc} GcJsonTexto
    Campo texto de primeiro nível de um JSON ("" se ausente ou inválido).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cJson, character, JSON
    @param cCampo, character, nome do campo
    @return character, valor
*/
User Function GcJsonTexto(cJson, cCampo)
    Local oJ := JsonObject():New() as object

    If ValType(oJ:FromJson(cJson)) == "C" .Or. ValType(oJ[cCampo]) != "C"
        Return ""
    EndIf
Return oJ[cCampo]

/*/{Protheus.doc} GcAgoraBrasilia
    Data e hora de Brasília (UTC-3, sem horário de verão desde 2019) no
    formato da DPS, independente do fuso do servidor.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @return character, AAAA-MM-DDThh:mm:ss-03:00
*/
User Function GcAgoraBrasilia()
    Local cUtc := DateTimeUTC() as character
    Local dDia := SToD(StrTran(Left(cUtc, 10), "-", "")) as date
    Local nH   := Val(SubStr(cUtc, 12, 2)) - 3 as numeric

    If nH < 0
        nH += 24
        dDia := dDia - 1
    EndIf
Return Left(DToS(dDia), 4) + "-" + SubStr(DToS(dDia), 5, 2) + "-" + Right(DToS(dDia), 2) + "T" + StrZero(nH, 2) + ;
    SubStr(cUtc, 14, 6) + "-03:00"

/*/{Protheus.doc} GcIsoData
    Data AAAA-MM-DD ou AAAAMMDD para AAAA-MM-DD ("" se inválida).
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cData, character, data
    @return character, AAAA-MM-DD
*/
User Function GcIsoData(cData)
    Local c := StrTran(AllTrim(cData), "-", "") as character

    If Len(c) != 8 .Or. Empty(SToD(c))
        Return ""
    EndIf
Return Left(c, 4) + "-" + SubStr(c, 5, 2) + "-" + Right(c, 2)

// Elemento XML com o texto escapado.
Static Function GcTag(cNome, cValor)
Return "<" + cNome + ">" + GcXmlTexto(cValor) + "</" + cNome + ">"

/*/{Protheus.doc} GcXmlTexto
    Escapa texto para XML (&, <, >) e tira quebras e espaços duplicados.
    @type User Function
    @author GesCon
    @since 2026-11-22
    @param cTxt, character, texto
    @return character, texto escapado
*/
User Function GcXmlTexto(cTxt)
    Local c := AllTrim(cTxt) as character

    c := StrTran(StrTran(StrTran(c, Chr(13), " "), Chr(10), " "), Chr(9), " ")
    While "  " $ c
        c := StrTran(c, "  ", " ")
    EndDo
Return StrTran(StrTran(StrTran(c, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")

// Valor no formato TSDec15V2 (ponto decimal, 2 casas).
Static Function GcDec2(nValor)
Return AllTrim(Str(Round(nValor, 2), 18, 2))
