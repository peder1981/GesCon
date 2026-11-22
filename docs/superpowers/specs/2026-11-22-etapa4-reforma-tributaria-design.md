# Etapa 4 — reforma tributária (IBS/CBS) no GesCon

## Por quê

Produto para síndicos e administradoras. A partir de 01/01/2027 o condomínio
edilício emite NFS-e das cobranças (mesmo sem ser contribuinte), e precisa
saber se o IBS e a CBS o alcançam (opção pelo regime regular, teste dos 80%).

## Fontes (texto lido em 2026-11-22)

| Norma | O que define |
|---|---|
| LC 214/2025, art. 26 (redação LC 227/2026), Câmara, texto consolidado | não contribuinte; opção pelo regime regular; § 2º I (optante: tudo) e II (não optante < 80%) |
| Decreto 12.955/2026 (Regulamento CBS), art. 25 | opção com permanência mínima de 12 meses; renúncia com efeito no ano seguinte |
| Decreto 12.955/2026, art. 115, VI, "d" | condomínio emite documento fiscal |
| Ato Conjunto RFB/CGIBS 4/2026, alterado pelo 7/2026 (DOU 13/11/2026) | NFS-e de condomínio: 01/12/2026 → 01/01/2027 |
| NT SE/CGNFS-e 009 v1.01, item 2.15; Anexo VI v1.04.01 | 99.05.01, grupo `IBSCBS/condominios`, vServ = Σ vCobranca, grupo imovel obrigatório |
| Anexo VIII v1.02.00 (correlação) | NBS 1.1001.90.00, cIndOp 020201, cClassTrib 200046 |
| Tabela cClassTrib (portal DF-e/SVRS) | 410012 "condomínio edilício não optante", CST 410, uso em NFS-e |

O artigo citado pelo operador (condomeeting) não cita norma; a data de
01/12/2026 dele foi superada pelo Ato Conjunto 7/2026.

## Abordagens

1. **Emitir pela API da Sefin Nacional (escolhida)**: DPS assinada com o A1 do
   condomínio. Única que atende a obrigação dentro do produto; exige o AdvPP
   ler PFX com cadeia (4.8.7).
2. Gerar o XML e o síndico subir no Emissor Nacional web: não existe upload de
   DPS no emissor web; descartada.
3. Integrar um serviço terceiro de emissão: custo e dado fiscal fora da
   máquina do cliente; descartada para o produto base.

## Decisões

- O GesCon não calcula IBS/CBS: na NFS-e nacional a Sefin calcula a partir do
  CST/cClassTrib. O teste dos 80% só informa e explica; enquadramento final é
  do contador.
- Período do teste dos 80%: a lei não fixa; padrão de 12 meses, editável.
- Uma DPS por cobrança, tpCobranca 01 (condomínio ordinário), sem
  detalhamento (opcional na NT).
- Senha do certificado nunca gravada; chave extraída para arquivo 0600 e
  apagada na hora.
- Número da DPS só é reservado depois de abrir o certificado; DPS rejeitada
  reaproveita o número.

## Verificação

- `tests/nfse_test.prw`: regras, teste dos 80%, DPS, assinatura, numeração.
- `scripts/check-nfse.py`: XSD oficial (+ grupo da NT 009), assinatura com
  lxml/cryptography, envio a Sefin simulada com mTLS (autoriza e rejeita).
- Navegador: telas Reforma tributária, Receitas e NFS-e contra a Sefin
  simulada.

## Pendente (fora do alcance verificável aqui)

- Emissão real na produção restrita: exige certificado A1 e CNPJ de um
  condomínio de verdade.
- XSD oficial com o grupo `condominios` (ainda não publicado em 20/10/2026).
- Cancelamento/substituição, gDetCobranca, descontos.
