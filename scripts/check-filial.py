#!/usr/bin/env python3
"""scripts/check-filial.py -- todo comando SQL que toca tabela de condomínio
(multi-filial) tem de filtrar ou gravar FILIAL.

Olha comando por comando (TCSqlQuery/TCSqlExec e montagens de cSql/cQry),
em src/*.prw e gescon.prw, fora de comentários e de blocos Protheus.doc.
A versão anterior (check-filial.sh) olhava arquivo por arquivo: bastava a
palavra FILIAL aparecer uma vez no arquivo, e o gescon.prw ficava de fora --
por isso a listagem de avisos sem filtro de condomínio passou.

Exceção legítima (tabela global por desenho, migração de schema): uma linha
`// check-filial: global -- <motivo>` logo antes do comando.
"""
import re
import sys
from pathlib import Path

TENANT = ("CON UNI DES COB RPT_INADIM RPT_EXTRATO RPT_DESCAT CFG_BOLETO GCT_TOKEN "
          "RPT_COND_COBRANCAS PLANO_CONTAS REPARTICAO EXERCICIO LANCAMENTOS "
          "RATEIO_DETALHE AUDITORIA RPT_BALANCETE AVISOS RPT_PORTAL_EXTRATOS "
          "RPT_PORTAL_AGENDA ANOMALIA_LOG ALERTA DASHBOARD_CACHE").split()
INICIO = re.compile(r'TCSql(Query|Exec)\(|\bc(Sql|Qry|Query)\w*\s*:=\s*"')
CONTINUA = re.compile(r'^\s*c(Sql|Qry|Query)\w*\s*\+=')
DDL = re.compile(r'PRAGMA|CREATE |ALTER |DROP |sqlite_master', re.I)
MARCA = "check-filial: global"


def sem_comentarios(linhas):
    """Troca por "" as linhas dentro de /*/ ... */ e o resto após //."""
    saida, em_bloco = [], False
    for linha in linhas:
        if em_bloco:
            saida.append("")
            if "*/" in linha:
                em_bloco = False
            continue
        if linha.lstrip().startswith("/*"):
            em_bloco = "*/" not in linha.split("/*", 1)[1]
            saida.append("")
            continue
        saida.append(linha)
    return saida


def checa(caminho):
    falhas = []
    original = caminho.read_text(encoding="utf-8", errors="replace").split("\n")
    linhas = sem_comentarios(original)
    i = 0
    while i < len(linhas):
        if not INICIO.search(re.sub(r'//.*', '', linhas[i])):
            i += 1
            continue
        comando, j = [linhas[i]], i
        while j + 1 < len(linhas) and (
                comando[-1].rstrip().endswith((";", "+")) or CONTINUA.match(linhas[j + 1])):
            j += 1
            comando.append(linhas[j])
        texto = " ".join(re.sub(r'//.*', '', c) for c in comando)
        tabelas = [t for t in TENANT if re.search(r'\b' + t + r'\b', texto)]
        anterior = original[i - 1] if i > 0 else ""
        if tabelas and "FILIAL" not in texto.upper() and not DDL.search(texto) and MARCA not in anterior:
            falhas.append(f"{caminho}:{i + 1}: {','.join(tabelas)} sem FILIAL :: {texto.strip()[:140]}")
        i = j + 1
    return falhas


def main():
    raiz = Path(__file__).resolve().parent.parent
    arquivos = sorted((raiz / "src").glob("*.prw")) + [raiz / "gescon.prw"]
    falhas = [f for a in arquivos for f in checa(a)]
    for f in falhas:
        print("FALHA: " + f)
    if falhas:
        print("check-filial: FALHOU")
        return 1
    print("check-filial: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
