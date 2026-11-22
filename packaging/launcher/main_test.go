package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"unicode"
)

// A senha inicial precisa passar na política do GesCon (GcPoliticaSenha):
// 10+ caracteres, maiúscula, minúscula, número e caractere especial.
func TestSenhaInicialAtendePolitica(t *testing.T) {
	vistas := map[string]bool{}
	for i := 0; i < 200; i++ {
		s, err := senhaInicial()
		if err != nil {
			t.Fatal(err)
		}
		var mai, min, dig, esp bool
		for _, r := range s {
			switch {
			case unicode.IsUpper(r):
				mai = true
			case unicode.IsLower(r):
				min = true
			case unicode.IsDigit(r):
				dig = true
			default:
				esp = true
			}
		}
		if len(s) < 10 || !mai || !min || !dig || !esp || strings.ContainsAny(s, "-_/+= ") {
			t.Fatalf("senha fora da política: %q", s)
		}
		if vistas[s] {
			t.Fatalf("senha repetida: %q", s)
		}
		vistas[s] = true
	}
}

func TestPrimeiroAcessoGravaEnvLegivelSoPeloDono(t *testing.T) {
	aberto := ""
	abrir = func(alvo string) error { aberto = alvo; return nil }
	d := t.TempDir()
	env := filepath.Join(d, "gescon.env")
	if err := primeiroAcesso(d, env); err != nil {
		t.Fatal(err)
	}
	m, err := lerEnv(env)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(m["GESCON_ADMIN_SENHA"], "Gc#7") || len(m) != 1 {
		t.Fatalf("env inesperado: %v", m)
	}
	if filepath.Base(aberto) != "PRIMEIRO-ACESSO.txt" {
		t.Fatalf("deveria abrir o aviso de primeiro acesso, abriu %q", aberto)
	}
	if fi, _ := os.Stat(env); fi.Mode().Perm() != 0o600 {
		t.Fatalf("permissão %v, esperada 0600", fi.Mode().Perm())
	}
}
