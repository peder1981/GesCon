// src/usuarios.prw — gestão de usuários e tokens temporários do GesCon.
// Menu "Usuários" com: Gerar Token, Revogar Token, Criar Usuário,
// Vincular-me a Condomínio, Voltar.
#include "totvs.ch"

/*/{Protheus.doc} GcGerarTokenId
    Gera o token de acesso do condômino: dois UUID v4 do runtime
    (UUIDRandom, gerador aleatório criptográfico) sem hífens = 64
    caracteres hexadecimais, 244 bits aleatórios. Antes era data + hora +
    Random() passados por SHA-256: previsível por quem soubesse a hora da
    emissão.
    @type User Function
    @author GesCon
    @since 2026-11-21
    @return character, token de 64 hex, ou "" se o runtime não gerou UUID
*/
User Function GcGerarTokenId()
    Local cU1 := StrTran(UUIDRandom(), "-", "") as character
    Local cU2 := StrTran(UUIDRandom(), "-", "") as character

    If Len(cU1) != 32 .Or. Len(cU2) != 32 .Or. cU1 == cU2
        Return ""
    EndIf
Return Lower(cU1 + cU2)
