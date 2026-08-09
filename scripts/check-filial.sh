#!/bin/sh
# scripts/check-filial.sh -- tripwire, nao prova formal: para cada .prw em
# src/ que chama TCSqlQuery/TCSqlExec E menciona uma das 22 tabelas
# por-condominio, exige que o mesmo arquivo tambem mencione "FILIAL" em
# algum lugar. Pega o caso "esqueci completamente do arquivo"; nao pega
# "filtrei 5 de 6 queries do mesmo arquivo" -- isso as checklists das
# Tasks 5-9 cobrem por leitura humana.
set -e
cd "$(dirname "$0")/.."

TENANT_TABLES="CON UNI DES COB RPT_INADIM RPT_EXTRATO RPT_DESCAT CFG_BOLETO GCT_TOKEN RPT_COND_COBRANCAS PLANO_CONTAS REPARTICAO EXERCICIO LANCAMENTOS RATEIO_DETALHE AUDITORIA RPT_BALANCETE AVISOS RPT_PORTAL_EXTRATOS RPT_PORTAL_AGENDA ANOMALIA_LOG ALERTA DASHBOARD_CACHE"

falhou=0
for f in src/*.prw; do
    [ -f "$f" ] || continue
    grep -q "TCSqlQuery(\|TCSqlExec(" "$f" || continue
    for t in $TENANT_TABLES; do
        if grep -qw "$t" "$f" && ! grep -q "FILIAL" "$f"; then
            echo "FALHA: $f menciona $t (com TCSqlQuery/TCSqlExec no arquivo) mas nunca FILIAL"
            falhou=1
            break
        fi
    done
done

if [ "$falhou" = 1 ]; then
    echo "check-filial: FALHOU"
    exit 1
fi
echo "check-filial: ok"
