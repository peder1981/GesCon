#!/usr/bin/env python3
"""scripts/check-nfse.py -- confere a NFS-e do GesCon com ferramentas que não
são o AdvPP (lxml e cryptography):

1. a DPS assinada gerada por tests/nfse_test.prw passa no XSD oficial da DPS
   v1.01 (tests/fixtures/nfse/xsd, com o grupo "condominios" da NT 009);
2. a assinatura confere: digest SHA-256 do infDPS canônico (C14N 1.0) e
   RSA-SHA256 do SignedInfo canônico com a chave do certificado do KeyInfo;
3. o envio: sobe uma Sefin simulada em HTTPS que EXIGE certificado de cliente
   da AC de teste, roda tests/nfse_envio.prw (GESCON_NFSE_URL apontando para
   ela) e confere que chegou {"dpsXmlGZipB64": ...} com uma DPS válida, e que o
   GesCon gravou a chave devolvida (e a rejeição, no segundo caso).

Uso: scripts/check-nfse.py <banco.db>   (o advplc da versão fixada no PATH)
"""
import base64
import copy
import gzip
import http.server
import json
import os
import ssl
import subprocess
import sys
import tempfile
import threading

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from lxml import etree

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIX = os.path.join(RAIZ, "tests", "fixtures", "nfse")
NS = {"n": "http://www.sped.fazenda.gov.br/nfse", "ds": "http://www.w3.org/2000/09/xmldsig#"}
CHAVE = ("3550308211222333000181" + "7" * 28)  # 50 dígitos, como a chave de acesso

ESQUEMA = etree.XMLSchema(etree.parse(os.path.join(FIX, "xsd", "DPS_v1.01.xsd")))


def c14n(el):
    """C14N 1.0 de uma subárvore. deepcopy de propósito: lxml 5.1 + libxml2
    2.12 põe xmlns="" errado nos netos quando um irmão (a Signature) declara
    outro namespace padrão."""
    return etree.tostring(copy.deepcopy(el), method="c14n")


def confere_dps(xml_bytes):
    """Valida no XSD e verifica a assinatura. Devolve a lista de problemas."""
    erros = []
    doc = etree.fromstring(xml_bytes)
    if not ESQUEMA.validate(doc):
        erros += ["XSD: %s" % e.message for e in ESQUEMA.error_log]
    inf = doc.find("n:infDPS", NS)
    sig = doc.find("ds:Signature", NS)
    if inf is None or sig is None:
        return erros + ["sem infDPS ou sem Signature"]
    ref = sig.find("ds:SignedInfo/ds:Reference", NS)
    if ref.get("URI") != "#" + inf.get("Id"):
        erros.append("Reference URI não aponta para o infDPS")
    digest = base64.b64encode(hashes_sha256(c14n(inf))).decode()
    if digest != sig.findtext("ds:SignedInfo/ds:Reference/ds:DigestValue", namespaces=NS):
        erros.append("DigestValue não confere com o infDPS canônico")
    der = base64.b64decode(sig.findtext("ds:KeyInfo/ds:X509Data/ds:X509Certificate", namespaces=NS))
    cert = x509.load_der_x509_certificate(der)
    try:
        cert.public_key().verify(
            base64.b64decode(sig.findtext("ds:SignatureValue", namespaces=NS)),
            c14n(sig.find("ds:SignedInfo", NS)),
            padding.PKCS1v15(), hashes.SHA256())
    except Exception as exc:  # noqa: BLE001 -- qualquer falha de verificação reprova
        erros.append("SignatureValue não confere: %r" % exc)
    return erros


def hashes_sha256(dados):
    h = hashes.Hash(hashes.SHA256())
    h.update(dados)
    return h.finalize()


class Sefin(http.server.BaseHTTPRequestHandler):
    """Sefin simulada: autoriza a primeira DPS válida, rejeita as seguintes."""
    recebidas = []

    def do_POST(self):  # noqa: N802 -- nome exigido pelo http.server
        corpo = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        cert = self.connection.getpeercert()
        try:
            dps = gzip.decompress(base64.b64decode(json.loads(corpo)["dpsXmlGZipB64"]))
            problemas = confere_dps(dps)
        except Exception as exc:  # noqa: BLE001
            dps, problemas = b"", ["corpo inválido: %r" % exc]
        Sefin.recebidas.append({"path": self.path, "ctype": self.headers.get("Content-Type"),
                                "cert": cert, "problemas": problemas, "dps": dps})
        if self.path != "/SefinNacional/nfse" or problemas or len(Sefin.recebidas) > 1:
            st, resp = 400, {"erros": [{"Codigo": "E9999", "Descricao": "Rejeitada pela simulação"}]}
        else:
            st, resp = 201, {"chaveAcesso": CHAVE, "idDps": etree.fromstring(dps).find("n:infDPS", NS).get("Id")}
        dados = json.dumps(resp).encode()
        self.send_response(st)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def log_message(self, *args):
        pass


def main():
    banco = sys.argv[1]
    falhas = []
    with tempfile.TemporaryDirectory() as tmp:
        saida = os.path.join(tmp, "dps.xml")
        env = dict(os.environ, GESCON_NFSE_SAIDA=saida)
        r = subprocess.run(["advplc", "run", "tests/nfse_test.prw", "--db-path", banco], cwd=RAIZ, env=env,
                           capture_output=True, text=True, timeout=300)
        if "todos os casos passaram" not in r.stdout:
            print(r.stdout[-2000:], r.stderr[-2000:])
            falhas.append("tests/nfse_test.prw não passou")
        elif not os.path.exists(saida):
            falhas.append("tests/nfse_test.prw não gravou a DPS")
        else:
            falhas += ["DPS do teste: " + p for p in confere_dps(open(saida, "rb").read())]

        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(os.path.join(FIX, "servidor.pem"), os.path.join(FIX, "servidor.key"))
        ctx.load_verify_locations(os.path.join(FIX, "ca.pem"))
        ctx.verify_mode = ssl.CERT_REQUIRED
        srv = http.server.HTTPServer(("127.0.0.1", 0), Sefin)
        srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        env = dict(os.environ, GESCON_NFSE_URL="https://localhost:%d/SefinNacional" % srv.server_port,
                   SSL_CERT_FILE=os.path.join(FIX, "ca.pem"))
        r = subprocess.run(["advplc", "run", "tests/nfse_envio.prw", "--db-path", banco], cwd=RAIZ, env=env,
                           capture_output=True, text=True, timeout=300)
        srv.shutdown()
        if "envio ok" not in r.stdout:
            print(r.stdout[-2000:], r.stderr[-2000:])
            falhas.append("tests/nfse_envio.prw não passou")
        if not Sefin.recebidas:
            falhas.append("a Sefin simulada não recebeu nada")
        for i, req in enumerate(Sefin.recebidas, 1):
            if req["ctype"] != "application/json":
                falhas.append("envio %d: Content-Type %s" % (i, req["ctype"]))
            if not req["cert"]:
                falhas.append("envio %d: sem certificado de cliente" % i)
            falhas += ["envio %d: %s" % (i, p) for p in req["problemas"]]

    for f in falhas:
        print("  FALHA " + f)
    print("check-nfse: %s (%d envio(s) recebidos pela Sefin simulada)" % ("ok" if not falhas else "FALHOU", len(Sefin.recebidas)))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
