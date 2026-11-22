# Documentação funcional — GesCon

Regras de negócio. Como usar cada tela: [Manual do usuário](../MANUAL_USUARIO.md).

## Visão geral

Gestão de condomínios: cadastro de unidades e condôminos, despesas do mês,
fechamento mensal com rateio por fração ideal, cobranças e pagamentos,
boleto, portal do condômino, comunicação, relatórios, contabilidade e
auditoria. Uma instalação atende vários condomínios; cada um tem os dados
separados (filial) e cada usuário só abre os condomínios a que tem acesso.

## Acesso e perfis

- **Super administrador**: todos os condomínios; cadastra condomínios e
  cria outros super administradores.
- **Síndico**: os condomínios vinculados a ele; cria síndicos do condomínio
  aberto. Não cadastra condomínio nem cria super administrador.
- **Condômino**: entra com token (uso único, 48 horas) emitido pela
  administração; vê só cobranças, boleto e avisos da própria unidade.
- Login único, sem diferenciar maiúsculas. Senha com 10+ caracteres,
  maiúscula, minúscula, número e especial, sem o login; troca obrigatória no
  primeiro acesso e depois de redefinida; 5 erros seguidos bloqueiam por 15
  minutos; 30 minutos sem uso encerram a sessão.
- Instalação nova: o administrador `admin` só nasce com a senha inicial de
  `GESCON_ADMIN_SENHA` (o pacote gera sozinho); não há senha padrão.

## Cadastros

- **Unidade**: código (até 10 letras, números, hífen ou barra), bloco,
  fração ideal (maior que 0, até 1) e condômino (precisa existir). Unidade
  com cobranças não é excluída.
- **Condômino**: código, nome, CPF/CNPJ (conferido pelo dígito; aceita o
  CNPJ alfanumérico da Receita, a partir de julho de 2026), e-mail (validado,
  usado na mala direta) e telefone. Condômino vinculado a unidade não é
  excluído.
- **Despesa**: competência `AAAA-MM`, descrição, categoria (define a conta
  contábil) e valor maior que zero, arredondado a 2 casas. Competência já
  fechada não recebe nem muda despesa.

## Fechamento mensal

Dada a competência, soma as despesas e gera uma cobrança por unidade:

```
cobrança da unidade = total de despesas da competência × fração ideal da unidade
```

- **Recusa** se a soma das frações ideais não estiver entre 99,9% e 100,1%,
  ou se a competência não estiver em `AAAA-MM`.
- **Uma vez por competência**: uma competência com cobranças não é fechada de
  novo (índice único por condomínio, competência e unidade). Exceção: se foi
  fechada sem exercício aberto e o exercício foi aberto depois, fechar de
  novo contabiliza (só os lançamentos).
- **Tudo ou nada**: as cobranças são gravadas num único comando; se falhar,
  nenhuma unidade é cobrada.
- **Soma exata**: o centavo que sobrar do rateio vai para a unidade de maior
  fração.
- **Valor travado**: mudar a fração depois não recalcula cobrança gerada.
- **Vencimento**: no mês seguinte, no dia escolhido (1 a 28; fora disso, 10).
- **Sem exercício aberto**: pergunta antes; as cobranças saem, a
  contabilização fica para depois.

## Pagamento e boleto

- Pagamento com data válida e não futura; cobrança já paga não é regravada.
- Cobrança vencida e não paga passa a "atrasado" (ao entrar e ao abrir os
  relatórios).
- Boleto: Itaú e Bradesco, padrão FEBRABAN (fator de vencimento com reinício
  em 22/02/2025), nosso número = número da cobrança; não sai para cobrança
  paga. Dados bancários conferidos pelo layout do banco ao gravar.

## Comunicação

- **Avisos**: publicados aparecem no portal do condômino; arquivados somem
  de lá.
- **Mala direta**: um e-mail por condômino com e-mail válido e cobrança em
  aberto na competência, com valor em reais e vencimento em DD/MM/AAAA.
  Exige SMTP configurado no servidor.

## Relatórios

Inadimplência (cobranças atrasadas com dias de atraso), extrato da unidade,
despesas por categoria e resultado do mês (recebido, despesas, saldo, em
aberto). Sempre do condomínio aberto, calculados na hora.

## Contabilidade

- Exercício (`AAAA-MM`, início e fim válidos); um ativo por vez.
- Lançamento manual em partida dobrada: data dentro do exercício ativo
  aberto, contas existentes e diferentes, valor maior que zero, histórico.
  Grava o login de quem lançou. Só lançamentos manuais podem ser alterados
  ou excluídos.
- Balancete por conta: ativo e despesa com saldo devedor (débito − crédito);
  passivo e receita com saldo credor.
- Fechar o exercício impede novos lançamentos nele.

## Limitações conhecidas

- Taxa extra (cobrança fora do fechamento mensal): fora da interface até a
  cobrança ter tipo próprio (o caminho antigo gerava vencimento em 31/02 e
  colidia com a regra de uma cobrança por unidade e competência).
- Repartição só por fração ideal.
- Boleto sem arquivo de remessa CNAB; Itaú sem as carteiras de nosso número
  com 15 posições.
- Reforma tributária (IBS/CBS, NFS-e de condomínio): em andamento.
