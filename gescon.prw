// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web com um menu real (FWMenuSelect, AdvPP v1.23.0+) navegando
// entre todas as telas sem reiniciar o processo. Login único de
// administrador (GcLogin) gate na frente do menu — sem papéis/permissões.
#include "totvs.ch"
#include "src/db.prw"
#include "src/schema-embed.prw"
#include "src/seguranca.prw"
#include "src/cobrancas.prw"
#include "src/fechamento.prw"
#include "src/malas.prw"
#include "src/relatorios.prw"
#include "src/usuarios.prw"
#include "src/portal.prw"
#include "src/portal-v2.prw"
#include "src/contabil.prw"
#include "src/auditoria.prw"
#include "src/auditoria-validacoes.prw"
#include "src/auth-primitives.prw"
#include "src/boleto.prw"
#include "src/cadastros.prw"
#include "src/consultas.prw"
#include "src/operacoes.prw"
#include "src/ui.prw"

/*/{Protheus.doc} GesCon
    Ponto de entrada do GesCon — `advplc serve gescon.prw`. Declara o
    estado da sessão (cada sessão do navegador é um programa próprio),
    prepara o banco e abre a interface web (src/ui.prw).
    @type User Function
    @author GesCon
    @since 2026-07-24
*/
User Function GesCon()
    Private g_cUniPortal      := ""
    Private g_cConPortal      := ""
    Private g_lAutoPortal     := .F.
    Private g_cFilialAtiva    := ""
    Private g_cCondNomePortal := ""
    Private cLoginAtual       := ""
    Private cGcPerfil         := ""
    Private cGcCondNome       := ""
    Private nGcUltimaAcao     := GcAgora()
    Private aGcRecarga        := {}

    ConOut("GesCon — Sistema de Gestão Condominial")
    // Antes de qualquer tela: sem isto a instalação nova abre contra um
    // banco sem tabela nenhuma.
    GcBootstrapDB()
    GcUI()
Return
