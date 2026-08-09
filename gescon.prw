// gescon.prw — ponto de entrada do GesCon. `advplc serve gescon.prw` sobe
// a UI web com um menu real (FWMenuSelect, AdvPP v1.23.0+) navegando
// entre todas as telas sem reiniciar o processo. Login único de
// administrador (GcLogin) gate na frente do menu — sem papéis/permissões.
#include "totvs.ch"
#include "src/db.prw"
#include "src/schema-embed.prw"
#include "src/login.prw"
#include "src/unidades.prw"
#include "src/condominos.prw"
#include "src/despesas.prw"
#include "src/cobrancas.prw"
#include "src/fechamento.prw"
#include "src/malas.prw"
#include "src/relatorios.prw"
#include "src/usuarios.prw"
#include "src/condominios-cadastro.prw"
#include "src/portal.prw"
#include "src/portal-v2.prw"
#include "src/contabil.prw"
#include "src/auditoria.prw"
#include "src/auditoria-validacoes.prw"
#include "src/auth-primitives.prw"
#include "src/boleto.prw"
#include "src/plano-contas.prw"
#include "src/exercicios.prw"
#include "src/auditoria-menu.prw"

/*/{Protheus.doc} GesCon
    Ponto de entrada do GesCon — sobe com `advplc serve gescon.prw`,
    mostra um menu navegando entre todas as telas.
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GesCon()
    Local aMenu := {"Unidades", "Condôminos", "Despesas", "Cobranças", "Fechamento Mensal", ;
        "Mala Direta", "Relatórios", "Contabilidade", "Auditoria", "Boletos", "Avisos", ;
        "Usuários", "Condomínios", "Trocar Senha", "Trocar Condomínio", "Sair"}
    Local nOpcao
    Local nEscolha
    Local cCompetencia
    Local nEnviados
    Local cDiaVenc
    Local nDiaVenc
    Local nPortal
    Local aPortal

    Private g_cUniPortal      := ""
    Private g_cConPortal      := ""
    Private g_lAutoPortal     := .F.
    Private g_cFilialAtiva    := ""
    Private g_cCondNomePortal := ""
    Private cLoginAtual    := ""

    ConOut("GesCon — Sistema de Gestão Condominial")

    // Antes de qualquer tela: sem isto o executável distribuído abre a
    // tela de login contra um banco sem tabela nenhuma.
    GcBootstrapDB()

    // Caminho de acesso: admin (login) ou condômino (token)
    Local aEscolha := {"Administrador", "Sou condômino"}
    nEscolha := FWMenuSelect(aEscolha, "Como deseja acessar?")

    Do Case
        Case nEscolha == 1
            If !GcLogin()
                MsgStop("Acesso não autorizado.", "GesCon")
                Return
            EndIf

            If !GcSelecionarCondominio(cLoginAtual)
                Return
            EndIf

            // Atualiza status "atrasado" logo após o login — reflete no resto da
            // sessão (Cobranças, Mala Direta) sem precisar abrir o relatório de
            // Inadimplência antes.
            GcAtualizarInadimplentes()

            Do While .T.
                nOpcao := FWMenuSelect(aMenu, "GesCon — Sistema de Gestão Condominial")
                Do Case
                    Case nOpcao == 1
                        GcUnidades()
                    Case nOpcao == 2
                        GcCondominos()
                    Case nOpcao == 3
                        GcDespesas()
                    Case nOpcao == 4
                        GcMenuCobrancas()
                    Case nOpcao == 5
                        cCompetencia := FWGetText("Fechar qual competência? (YYYY-MM)", "")
                        If !Empty(cCompetencia)
                            cDiaVenc := FWGetText("Dia do vencimento no mês seguinte? (1-28)", "10")
                            nDiaVenc := Val(cDiaVenc)
                            If GcFecharMes(cCompetencia, nDiaVenc)
                                MsgInfo("Competência " + cCompetencia + " fechada com sucesso.", "Fechamento Mensal")
                            Else
                                MsgAlert("Não foi possível fechar " + cCompetencia + " — já fechada ou sem unidade cadastrada.", "Fechamento Mensal")
                            EndIf
                        EndIf
                    Case nOpcao == 6
                        cCompetencia := FWGetText("Mala direta de qual competência? (YYYY-MM)", "")
                        If !Empty(cCompetencia)
                            nEnviados := GcMalaDireta(cCompetencia)
                            MsgInfo(Str(nEnviados) + " e-mail(s) enviado(s).", "Mala Direta")
                        EndIf
                    Case nOpcao == 7
                        GcMenuRelatorios()
                    Case nOpcao == 8
                        GcMenuContabilidade()
                    Case nOpcao == 9
                        GcMenuAuditoria()
                    Case nOpcao == 10
                        GcMenuBoletos()
                    Case nOpcao == 11
                        GcMenuAvisos()
                    Case nOpcao == 12
                        GcMenuUsuarios()
                    Case nOpcao == 13
                        GcCadastroCondominios()
                    Case nOpcao == 14
                        GcTrocarSenha()
                    Case nOpcao == 15
                        GcSelecionarCondominio(cLoginAtual)
                    Otherwise
                        Exit
                EndCase
            EndDo
        Case nEscolha == 2
            If !GcPortalCondmino()
                MsgStop("Acesso não autorizado.", "GesCon")
                Return
            EndIf

            // Menu do portal do condômino (read-only)
            Do While .T.
                aPortal := {"Minhas Cobranças", "Sair"}
                nPortal := FWMenuSelect(aPortal, "Portal do Condômino")
                Do Case
                    Case nPortal == 1
                        GcPortalBrowse()
                    Otherwise
                        GcSairPortal()
                        Exit
                EndCase
            EndDo
    EndCase
Return

/*/{Protheus.doc} GcMenuRelatorios
    Submenu de relatórios — Balancete Mensal, Inadimplência, Extrato
    por Unidade, Despesas por Categoria.
    @type Function
    @author GesCon
    @since 2026-07-24
*/
User Function GcMenuRelatorios()
    Local aMenu := {"Balancete Mensal", "Inadimplência", "Extrato por Unidade", "Despesas por Categoria", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Relatórios")
    Local cCompetencia
    Local cUnidade

    Do Case
        Case nOpcao == 1
            cCompetencia := FWGetText("Balancete de qual competência? (YYYY-MM)", "")
            If !Empty(cCompetencia)
                GcBalanceteMensal(cCompetencia)
            EndIf
        Case nOpcao == 2
            GcInadimplencia()
        Case nOpcao == 3
            cUnidade := FWGetText("Extrato de qual unidade?", "")
            If !Empty(cUnidade)
                GcExtratoUnidade(cUnidade)
            EndIf
        Case nOpcao == 4
            cCompetencia := FWGetText("Despesas por categoria de qual competência? (vazio = todas)", "")
            GcDespesasCategoria(cCompetencia)
    EndCase
Return

/*/{Protheus.doc} GcMenuContabilidade
    Submenu de contabilidade — acesso a funções de validação, balancete,
    auditoria e fechamento de período.
    @type Function
    @author GesCon
    @since 2026-07-30
*/
User Function GcMenuContabilidade()
    Local aMenu := {"Lançamentos", "Validar Integridade", "Gerar Balancete", "Auditar Período", ;
        "Fechar Período", "Plano de Contas", "Tipos de Repartição", "Exercícios", ;
        "Abrir Exercício", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Contabilidade")
    Local cExercicio
    Local lRet
    Local nSaldo
    Local nAnomalias

    Do Case
        Case nOpcao == 1
            GcMenuLancamentos()
        Case nOpcao == 2
            cExercicio := GcExercicioAtivo()
            If Empty(cExercicio)
                MsgAlert("Nenhum exercício ativo.", "Contabilidade")
            Else
                lRet := GcValidarIntegridade(cExercicio)
                If lRet
                    MsgInfo("Exercício " + cExercicio + " em equilíbrio (débitos == créditos).", "Validação de Integridade")
                Else
                    MsgAlert("Exercício " + cExercicio + " apresenta desequilíbrio contábil.", "Validação de Integridade")
                EndIf
            EndIf
        Case nOpcao == 3
            cExercicio := GcExercicioAtivo()
            If Empty(cExercicio)
                MsgAlert("Nenhum exercício ativo.", "Contabilidade")
            Else
                nSaldo := GcGerarBalancetePeriodo(cExercicio)
                MsgInfo("Balancete de " + cExercicio + " gerado (saldo=" + cValToChar(nSaldo) + ").", "Gerar Balancete")
            EndIf
        Case nOpcao == 4
            cExercicio := GcExercicioAtivo()
            If Empty(cExercicio)
                MsgAlert("Nenhum exercício ativo.", "Contabilidade")
            Else
                nAnomalias := GcAuditoriaFecharPeriodo(cExercicio)
                If nAnomalias = 0
                    MsgInfo("Auditoria de " + cExercicio + " OK (0 anomalias críticas).", "Auditoria")
                Else
                    MsgAlert("Auditoria detectou " + cValToChar(nAnomalias) + " anomalias críticas no exercício " + cExercicio + ".", "Auditoria")
                EndIf
            EndIf
        Case nOpcao == 5
            cExercicio := GcExercicioAtivo()
            If Empty(cExercicio)
                MsgAlert("Nenhum exercício ativo.", "Contabilidade")
            Else
                lRet := GcFecharPeriodo(cExercicio)
                If lRet
                    MsgInfo("Período " + cExercicio + " fechado com sucesso.", "Fechamento")
                Else
                    MsgAlert("Não foi possível fechar período " + cExercicio + ".", "Fechamento")
                EndIf
            EndIf
        Case nOpcao == 6
            GcPlanoContas()
        Case nOpcao == 7
            GcReparticao()
        Case nOpcao == 8
            GcExercicios()
        Case nOpcao == 9
            GcAbrirExercicio()
    EndCase
Return

/*/{Protheus.doc} GcMenuCobrancas
    Submenu de cobranças: consulta em grade e registro de pagamento.
    O registro de pagamento precisa de uma cobrança escolhida, o que o
    FWMBrowse não devolve -- daí GcSelecionarCobranca.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcMenuCobrancas()
    Local aMenu := {"Consultar Cobranças", "Registrar Pagamento", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Cobranças")
    Local nRecno := 0
    Local cData  := ""

    Do Case
        Case nOpcao == 1
            GcCobrancas()
        Case nOpcao == 2
            nRecno := GcSelecionarCobranca("pendente", "Registrar pagamento de qual cobrança?")
            If nRecno > 0
                cData := AllTrim(FWGetText("Data do pagamento (AAAAMMDD):", DtoS(Date())))
                If Len(cData) != 8
                    MsgAlert("Data deve estar no formato AAAAMMDD.", "Registrar Pagamento")
                Else
                    If GcRegistrarPagamento(nRecno, SToD(cData))
                        MsgInfo("Pagamento registrado.", "Registrar Pagamento")
                    Else
                        MsgAlert("Não foi possível registrar o pagamento.", "Registrar Pagamento")
                    EndIf
                EndIf
            EndIf
    EndCase
Return

/*/{Protheus.doc} GcMenuBoletos
    Submenu de boletos: configuração bancária e emissão por cobrança.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcMenuBoletos()
    Local aMenu := {"Configurar Dados Bancários", "Gerar Boleto de uma Cobrança", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Boletos")
    Local nRecno := 0

    Do Case
        Case nOpcao == 1
            GcBoletoConfigurar()
        Case nOpcao == 2
            nRecno := GcSelecionarCobranca("", "Gerar boleto de qual cobrança?")
            If nRecno > 0
                GcBoletoGera(nRecno)
            EndIf
    EndCase
Return

/*/{Protheus.doc} GcMenuAvisos
    Submenu de avisos do condomínio: consulta, criação e arquivamento.
    @type Function
    @author GesCon
    @since 2026-07-31
*/
User Function GcMenuAvisos()
    Local aMenu := {"Consultar Avisos", "Criar Aviso", "Arquivar Aviso", "Voltar"}
    Local nOpcao := FWMenuSelect(aMenu, "Avisos")
    Local oBrowse
    Local cTitulo := ""
    Local cCorpo  := ""
    Local aAvisos := {}
    Local aItens  := {}
    Local nI      := 0
    Local nEscolha := 0

    Do Case
        Case nOpcao == 1
            oBrowse := FWMBrowse():New()
            oBrowse:SetAlias("AVISOS")
            oBrowse:SetDescription("Avisos do Condomínio")
            oBrowse:Activate()
        Case nOpcao == 2
            cTitulo := AllTrim(FWGetText("Título do aviso:", ""))
            If Empty(cTitulo)
                Return
            EndIf
            cCorpo := AllTrim(FWGetText("Texto do aviso:", ""))
            If Empty(cCorpo)
                Return
            EndIf
            If GcCriarAviso(cTitulo, cCorpo)
                MsgInfo("Aviso publicado.", "Criar Aviso")
            Else
                MsgAlert("Não foi possível publicar o aviso.", "Criar Aviso")
            EndIf
        Case nOpcao == 3
            aAvisos := TCSqlQuery("SELECT AVI_ID, AVI_TITULO FROM AVISOS " + ;
                "WHERE AVI_ATIVO = 1 AND D_E_L_E_T_ = ' ' ORDER BY AVI_DATA_CRIACAO DESC")

            If Len(aAvisos) == 0
                MsgInfo("Nenhum aviso ativo.", "Arquivar Aviso")
                Return
            EndIf

            For nI := 1 To Len(aAvisos)
                AAdd(aItens, AllTrim(aAvisos[nI]["AVI_TITULO"]))
            Next nI
            AAdd(aItens, "Voltar")

            nEscolha := FWMenuSelect(aItens, "Arquivar qual aviso?")

            If nEscolha > 0 .And. nEscolha <= Len(aAvisos)
                If GcArquivarAviso(Val(aAvisos[nEscolha]["AVI_ID"]))
                    MsgInfo("Aviso arquivado.", "Arquivar Aviso")
                Else
                    MsgAlert("Não foi possível arquivar o aviso.", "Arquivar Aviso")
                EndIf
            EndIf
    EndCase
Return
