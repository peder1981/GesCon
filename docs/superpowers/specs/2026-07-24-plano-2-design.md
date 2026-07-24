# GesCon — Plano 2 Design (4 itens)

**Data**: 2026-07-24
**Status**: aprovado pelo usuário
**Escopo**: Papéis de usuário, senha mascarada, boleto bancário, portal do condômino

---

## Visão geral

Plano 1 entregou o motor financeiro núcleo (cadastros, fechamento mensal, cobranças, mala direta, relatórios). Plano 2 entrega os 4 itens restantes:

1. **Papéis de usuário + token temporário** — admin gera tokens para condôminos acessarem leitura limitada
2. **Senha mascarada** — `FWGetText` suporta campo password em web e desktop
3. **Boleto bancário** — geração de código de barras Itaú/Bradesco (texto formatado)
4. **Portal do condômino** — acesso por token, apenas leitura de cobranças da unidade

**Ordem de implementação:**
1. Item 2 (AdvPP) — depende de nenhuma outra etapa
2. Item 3 (AdvPP + GesCon) — só precisa de item 2 estar pronto para testar
3. Items 1+4 combinados (GesCon) — dependem do novo schema e das funcionalidades existentes

---

## Item 1 + 4: Papéis de Usuário + Token + Portal Condômino

### Nova tabela GCT_TOKEN

```sql
CREATE TABLE GCT_TOKEN (
    TOKEN TEXT PRIMARY KEY,           -- UUID 36 chars
    USR_LOGIN TEXT NOT NULL,          -- quem gerou
    CON_CODIGO TEXT NOT NULL,         -- condômino destino
    UNI_CODIGO TEXT NOT NULL,         -- unidade vinculada
    CRIPTADO TEXT NOT NULL,           -- timestamp criação "YYYY-MM-DD HH:MM:SS"
    VALIDO_ATE TEXT NOT NULL,         -- validade "YYYY-MM-DD HH:MM:SS" (+48h)
    USADO INTEGER DEFAULT 0,          -- 0=pendente, 1=usado
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0
);
```

Metadados SX3 pros 5 campos de negócio + padrão Protheus.

### Tabela RPT_COND_COBRANCAS

```sql
CREATE TABLE RPT_COND_COBRANCAS (
    RCC_UNIDADE TEXT NOT NULL,
    RCC_COMPET TEXT NOT NULL,
    RCC_VALOR REAL,
    RCC_VENCTO TEXT,
    RCC_STATUS TEXT,
    RCC_DTPAG TEXT,
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0
);
```

Snapshot das cobranças filtradas por unidade — segue padrão dos relatórios existentes.

### Fluxo Admin → Gerar Token

1. Menu "Usuários" → "Gerar token"
2. Lista condôminos com email (JOIN CON-UNI)
3. Admin seleciona um condômino
4. Sistema gera UUID36, calcula `valido_ate = now() + 48h`
5. Grava em GCT_TOKEN
6. Mostra token em MsgInfo: "Token: XXXX-XXXX-... Válido até: YYYY-MM-DD HH:MM"
7. Opcional: se SMTP configurado, envia email automático com TMailMessage

### Fluxo Admin → Revogar Token

1. Menu "Usuários" → "Revogar token"
2. Lista tokens ativos (VALIDO_ATE > agora AND USADO=0 AND D_E_L_E_T_=' ')
3. Admin seleciona → DELETE lógico na GCT_TOKEN

### Fluxo Admin → Criar Usuário Tradicional

1. Menu "Usuários" → "Criar usuário"
2. Seleciona tipo: Admin ou Condômino
3. Se Admin: pede login/senha → INSERT na USR com USR_PERFIL='ADMIN'
4. Se Condômino: seleciona da lista de condôminos → cria USR_PERFIL='CONDOMINO' (sem login ainda, será adicionado no futuro)

### Fluxo Login Condômino

1. Tela de login mostra botão "Sou condômino"
2. Condômino cola o token recebido
3. `GcAuthCondômino(cToken)`:
   - Busca GCT_TOKEN por TOKEN = cToken, D_E_L_E_T_=' ', VALIDO_ATE > agora, USADO=0
   - Se encontrado: marca USADO=1, busca uni_codigopela tabela
   - Abre RPT_COND_COBRANCAS filtrado por essa unidade
4. Se token inválido/expirado/usado → MsgStop

### Fluxo Portal Condômino

Após autenticação bem-sucedida:
1. Menu com uma opção: "Minhas Cobranças"
2. Abre RPT_COND_COBRANCAS (recalculado do zero antes do browse)
3. Opção "Sair"

### Arquivos novos (GesCon)
- `src/usuarios.prw` — menu de gestão de usuários (listar, criar, gerar token, revogar)
- `src/portal.prw` — autenticação condômino via token + portal browse limitado

### Arquivos modificados (GesCon)
- `gescon.prw` — inclui novos arquivos, adiciona "Usuários" ao menu principal, branch condômino no login
- `schema.sql` — GCT_TOKEN + RPT_COND_COBRANCAS + SX3
- `scripts/bootstrap-db.sh` — sem mudanças

---

## Item 2: Senha Mascarada

### Interface UIProvider (Go)

```go
type UIProvider interface {
    // ... métodos existentes ...
    InputText(prompt, def string, bIsPassword bool) string
}
```

Muda de `InputText(prompt, def string)` para `InputText(prompt, def string, bIsPassword bool)`. Zero quebra — todos os chamadores passam `.F.` (default).

### Native FWGetText (Go)

```go
"FWGETTEXT": func(args []advplrt.Value) (advplrt.Value, error) {
    prompt := getArgString(args, 0, "")
    def := getArgString(args, 1, "")
    bPasswd := false
    if len(args) > 2 {
        bPasswd = advplrt.ToBool(getArg(args, 2))
    }
    return advplrt.NewString(v.uiProvider.InputText(prompt, def, bPasswd)), nil
},
```

Terceiro argumento opcional. `FWGetText("label", "default")` funciona como antes. `FWGetText("label", "default", .T.)` ativa modo password.

### Fyne UI (Go)

```go
func (p *FyneUIProvider) InputText(prompt, def string, bIsPassword bool) string {
    d := fyne.NewPasswordDialog(prompt, p.window) // ou NewDialog se !bIsPassword
    d.SetEntryPassword(bIsPassword) // entry.Password = bIsPassword
    // ...
}
```

### Angular Web (TypeScript)

```typescript
interface InputSpec { prompt: string; def: string; pw?: boolean; }
```

No template HTML: `<input type="{{ inputSpec()?.pw ? 'password' : 'text' }}">`

Os campos `PoDynamicFormField` precisam refletir o tipo corredo. Se `pw===true`, usar `type: 'password'` no campo.

### GesCon uso

Todas as chamadas de `FWGetText` para senhas passam a usar `.T.` como 3º argumento:
- `GcCriarAdmin()` — linha 52
- `GcAutenticar()` — linha 75
- `GcTrocarSenha()` — linhas 119, 124

---

## Item 3: Boleto Bancário

### Tabela CFG_BOLETO (configuração única)

```sql
CREATE TABLE CFG_BOLETO (
    CFG_BANCO TEXT NOT NULL DEFAULT '237',     -- '1' (Itaú) ou '237' (Bradesco)
    CFG_AGENCIA TEXT NOT NULL,                  -- agência (4-5 digits + DV)
    CFG_CONTA TEXT NOT NULL,                    -- conta corrente (6-7 digits + DV)
    CFG_COBRT TEXT NOT NULL,                    -- carta/cedente (Bradesco) ou convênio (Itaú)
    CFG_CARTEIRA TEXT NOT NULL,                 -- carteira (ex: '174', '104')
    R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT,
    D_E_L_E_T_ TEXT DEFAULT ' ',
    R_E_C_D_E_L_ INTEGER DEFAULT 0
);
```

A tabela tem UMA linha (registro com R_E_C_N_O_=1), estilo MV configuráveis do Protheus.

Metadados SX3 pros 5 campos.

### Funções geradoras (pure AdvPL, sem bibliotecas externas)

**GcBoletoGera(cCobrancaRecno):**
1. Busca dados da COB e da CFG_BOLETO
2. Monta os 47 digits do código de barras (padrão FEBRABAN)
3. Gera linha digitável a partir dos 47 digits (4 grupos + DV)
4. Grava GCT_BOLETO

**GcBoletoCamposFebraban(cBanco, cAgencia, cConta, cCobrta, cCarteira, cNumeroDocumento, cValor, cInstrucao):**
Retorna array de 47 chars numéricos, posicionados conforme tabelas FEBRABAN.

Algoritmo posicional:
- Posição 1-3: código do banco (001, 033, 237)
- Posição 4-7: moeda (9=Real)
- Posição 8-8: versão do layout (2)
- Posição 9-9: feira (0=fator pagamento, 9 para não-fator)
- Posição 10-13: fator pagamento (dias desde 07/1997)
- Posição 14-24: valor (9 dígitos, compensa esquerda com zeros, sem ponto/vírgula)
- Posição 25-50: campo livre (32 chars — estrutura muda por banco)
- Posição 51-52: DV (módulo 11 sobre campos 1-4)

Estrutura do campo livre (posição 25-56):
- **Itaú (banco 341)**:
  - Pos 25-26: carteira (2 chars)
  - Pos 27-31: agência (5 chars, preenchido com zeros)
  - Pos 32: DV da agência
  - Pos 33-37: conta corrente (5 chars, preenchido com zeros)
  - Pos 38: DV da conta
  - Pos 39: identificador (3 = factura)
  - Pos 40-44: número do documento (5 chars, zeros à esquerda)
  - Pos 45-50: sacado (6 chars, zeros à esquerda)
  - Pos 51-52: DV campo livre (módulo 11)

- **Bradesco (banco 237)**:
  - Pos 25-28: convenio (4 chars, preenchido com zeros)
  - Pos 29-33: agência (5 chars, preenchido com zeros)
  - Pos 34-38: conta (5 chars, preenchido com zeros)
  - Pos 39: DV da conta
  - Pos 40-47: carteira (8 chars, preenchido com zeros)
  - Pos 48:DV carteira
  - Pos 49-52: número do documento (4 chars)
  - Pos 53-56:DV documento (módulo 11)

**GcBoletoLinhaDigitavel(aDigits):**
Retorna string formatada com pontos e hífen separando os 5 blocos + DV individual de cada bloco.

Formato: `XX.XXXX.XXXX X XXXX XXXX XXXX XXXX XX X DV`

Exemplo Itaú: `34191.12345 67890123 4 56789012345 6 74840000001234`

**GcBoletoCodigoBarras(aDigits):**
Retorna string com os 47 dígitos agrupados: 6 espaços nos pontos separadores FEBRABAN.

Exemplo: `34191123456789012345678901234567890123456 74840000001234`

**GcBoletoExibe(nRecno):**
Mostra o boleto em MsgInfo: dados do beneficiário, dados do cobrado, linha digitável, código de barras.

### Tela de configuração de boleto

Novo item no menu admin: "Configurar Boleto"

Usa `FWMBrowse` sobre `CFG_BOLETO` com alias fixo `"CFG_BOLETO"` — como é uma tabela de 1 linha, o admin edita os campos diretamente.

Ou melhor: como `FWMBrowse` sobre tabela específica de configuração não faz sentido (ela tem muitos inserts futuros se o admin editar), usamos uma abordagem customizada similar à do login:

```advpl
User Function GcConfigBoleto()
    // Pede dados manualmente com FWGetText (e FWGetPassword pra senha em breve)
    Local cBanco := FWGetText("Código do banco? ('1'=Itaú, '237'=Bradesco)", "237")
    Local cAgencia := FWGetText("Agência?", "1234")
    Local cConta := FWGetText("Conta corrente?", "12345-6")
    Local cCobrta := FWGetText("Carta/Cedente ou Convênio?", "1234")
    Local cCarteira := FWGetText("Carteira?", "174")
    
    // Salva ou atualiza a linha 1 da CFG_BOLETO
    TCSqlExec("DELETE FROM CFG_BOLETO WHERE D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO CFG_BOLETO (CFG_BANCO, CFG_AGENCIA, CFG_CONTA, CFG_COBRT, CFG_CARTEIRA) VALUES (...)")
Return
```

### Arquivos novos (GesCon)
- `src/boleto.prw` — todas as funções de geração de boleto
- `tests/boleto_test.prw` — testes da linha digitável e código de barras

### Arquivos modificados (GesCon)
- `gescon.prw` — nova opção "Boletos" no menu admin
- `schema.sql` — CFG_BOLETO, GCT_BOLETO, SX3

---

## Limitações e decisões registradas

- **Token de condômino é texto puro, não URL.** Não sabemos a URL do servidor (pode ser localhost, IP interno, domínio externo). O admin repassa o token manualmente (por WhatsApp, SMS, etc).
- **Condômino por token só vê leitura.** Não pode alterar cobranças, nem registrar pagamentos. Isso é Plano 3.
- **Senha mascarada éADVPL nativo, não criptografia.** Esconde caracteres no display, mas não protege contra keyloggers ou logs do sistema — isso é uma melhoria UX, não segurança.
- **Boleto é código de barras textual.** Sem imagem visual (SVG/PNG/barcode library). Números são suficiente para o banco processar.
- **Nenhum desses itens requer migração de dados existentes.** Tudo é add-only: novas tabelas, nova coluna USR_PERFIL, nova native opcional.
