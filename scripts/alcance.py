#!/usr/bin/env python3
"""scripts/alcance.py -- confere que toda funcao de negocio tem caminho de menu.

O criterio de "integralmente funcional" deste projeto: nenhuma User Function
Gc* de src/ pode ficar sem caminho de chamada a partir de GesCon(). Ja
aconteceu de modulos inteiros (boleto, validadores de auditoria) existirem
compilados e inalcancaveis -- codigo escrito, testado e invisivel ao usuario.

Percorre o grafo de chamadas a partir do ponto de entrada e falha se sobrar
alguem fora, exceto o que estiver em DIFERIDAS com a razao registrada.
"""
import glob
import re
import sys

# Funcoes que ficam de proposito fora do menu, com o porque. Cada entrada
# aqui e uma decisao consciente, nao um esquecimento.
DIFERIDAS = {
    "GcValidarToken":      "auth do portal do condomino, fase adiada",
    "GcValidarLoginPortal":"auth do portal do condomino, fase adiada",
    "GcInvalidarToken":    "auth do portal do condomino, fase adiada",
    "GcGerarTokenUnico":   "auxiliar das primitivas de auth do portal",
    "GcIsoToDate":         "auxiliar das primitivas de auth do portal",
    "GcDataHoraIso":       "auxiliar das primitivas de auth do portal",
    "GcPortalCondominoV2": "portal do condomino v2, fase adiada",
}


def corpos():
    """Mapeia nome -> corpo da funcao, sem comentarios."""
    corpo, onde = {}, {}
    for caminho in ["gescon.prw"] + sorted(glob.glob("src/*.prw")):
        txt = open(caminho, encoding="utf-8").read()
        txt = re.sub(r"/\*.*?\*/", "", txt, flags=re.S)
        txt = re.sub(r"^\s*//.*$", "", txt, flags=re.M)
        marcas = [
            (m.start(), m.group(1))
            for m in re.finditer(r"^(?:User |Static )?Function\s+(\w+)", txt, re.M)
        ]
        for i, (pos, nome) in enumerate(marcas):
            fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(txt)
            corpo[nome] = txt[pos:fim]
            onde[nome] = caminho
    return corpo, onde


def main():
    corpo, onde = corpos()

    if "GesCon" not in corpo:
        print("alcance: ponto de entrada GesCon() nao encontrado")
        return 1

    vistos, fila = set(), ["GesCon"]
    while fila:
        nome = fila.pop()
        if nome in vistos or nome not in corpo:
            continue
        vistos.add(nome)
        fila.extend(c for c in set(re.findall(r"\b(\w+)\s*\(", corpo[nome])) if c in corpo)

    negocio = [n for n in corpo if n.startswith("Gc")]
    orfas = sorted(n for n in negocio if n not in vistos and n not in DIFERIDAS)

    print("alcance: %d funcoes Gc*, %d alcancaveis, %d diferidas"
          % (len(negocio), len(vistos & set(negocio)), len(DIFERIDAS)))

    if orfas:
        print("alcance: %d sem caminho de menu" % len(orfas))
        for n in orfas:
            print("  FALHA %s (%s)" % (n, onde[n]))
        return 1

    print("alcance: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
