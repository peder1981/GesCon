package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
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

// --encerrar mata os processos de gescon.pid e apaga o arquivo.
func TestEncerrarMataOsProcessosDoArquivo(t *testing.T) {
	cmd := exec.Command("sleep", "60")
	if err := cmd.Start(); err != nil {
		t.Skip("sem sleep:", err)
	}
	arq := filepath.Join(t.TempDir(), "gescon.pid")
	if err := os.WriteFile(arq, []byte(strconv.Itoa(cmd.Process.Pid)+" 999999999\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	encerrar(arq)
	feito := make(chan error, 1)
	go func() { feito <- cmd.Wait() }()
	select {
	case <-feito:
	case <-time.After(5 * time.Second):
		t.Fatal("processo continuou vivo")
	}
	if _, err := os.Stat(arq); !os.IsNotExist(err) {
		t.Fatal("gescon.pid deveria ser apagado")
	}
}
