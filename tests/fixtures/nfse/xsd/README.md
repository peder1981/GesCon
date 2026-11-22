# Artefatos de teste da NFS-e (somente testes)

- `xsd/`: esquemas oficiais da DPS v1.01 (produção restrita, pacote de
  20/10/2026, gov.br/nfse). Única alteração, marcada com comentário
  "GesCon": o grupo `IBSCBS/condominios` da NT SE/CGNFS-e 009 v1.01 (item
  2.15), que esse pacote ainda não traz. Quando sair o XSD oficial com o
  grupo, substitua os arquivos.
- `ca.pem`: AC de teste. `a1-teste.pfx` (senha `teste123`): certificado de
  cliente "CONDOMINIO TESTE" emitido por ela, exportado com cifra legada e
  com a cadeia, como um A1 da ICP-Brasil exportado pelo Windows.
- `servidor.pem`/`servidor.key`: certificado de "localhost" da mesma AC,
  para a Sefin simulada de `scripts/check-nfse.py`.

Nenhum destes certificados vale fora dos testes.
