#!/usr/bin/env python3
"""Confere que o lançador e o instalador concordam sobre os caminhos.

O lançador procura o programa num caminho relativo compilado dentro dele
(`app\\GesConApp-windows-amd64.exe`) e cria a pasta do banco compartilhado
num caminho absoluto. O instalador decide onde cada arquivo é gravado. São
dois arquivos que ninguém edita junto, e um erro aqui só apareceria numa
máquina Windows, como caixa de diálogo dizendo que o programa não foi
encontrado.
"""
import re
import sys
from pathlib import Path

raiz = Path(__file__).resolve().parent.parent
iss = (raiz / "installer" / "gescon.iss").read_text(encoding="utf-8")
go = (raiz / "installer" / "launcher" / "main.go").read_text(encoding="utf-8")

falhas = []


def const_go(nome: str) -> str | None:
    m = re.search(rf"{nome}\s*=\s*`([^`]+)`", go)
    return m.group(1) if m else None


programa = const_go("programa")
banco = const_go("bancoCompartilhado")

if programa is None:
    falhas.append("nao achei a constante `programa` em launcher/main.go")
if banco is None:
    falhas.append("nao achei a variavel `bancoCompartilhado` em launcher/main.go")

if programa:
    # `app\GesConApp-windows-amd64.exe` tem que bater com o DestDir + nome do
    # Source correspondente no [Files].
    subpasta, _, exe = programa.rpartition("\\")
    alvo = f'Source: "{exe}"; DestDir: "{{app}}\\{subpasta}"'
    if alvo not in iss:
        falhas.append(
            f"o lancador procura {programa!r}, mas o .iss nao tem {alvo!r}"
        )

if banco:
    # O lancador cria a pasta do banco; o instalador precisa ter dado
    # permissao de escrita nela, senao so o primeiro usuario consegue gravar.
    pasta = banco.rsplit("\\", 1)[0]
    nome = pasta.rsplit("\\", 1)[-1]
    if f'Name: "{{commonappdata}}\\{nome}"; Permissions: users-modify' not in iss:
        falhas.append(
            f"o banco fica em {pasta!r}, mas o .iss nao concede users-modify "
            f'em {{commonappdata}}\\{nome}'
        )
    if not pasta.lower().startswith("c:\\programdata\\"):
        falhas.append(
            f"o banco compartilhado deveria estar sob C:\\ProgramData, esta em {pasta!r}"
        )

# Nenhum atalho pode apontar direto para o programa: seria um caminho que
# pula o lancador e cai no banco por usuario -- o furo que este desenho
# existe para fechar.
for linha in iss.splitlines():
    if linha.startswith("Name:") and "Filename:" in linha and "GesConApp" in linha:
        falhas.append(f"atalho pula o lancador: {linha.strip()}")

print("instalador (lancador e .iss coerentes):")
if falhas:
    for f in falhas:
        print(f"  FALHA {f}")
    sys.exit(1)
print("  ok")
