// gescon-launcher: inicia o GesCon numa máquina só (escritório do condomínio
// ou da administradora). Só biblioteca padrão.
//
//   - dados do usuário em %LOCALAPPDATA%\GesCon (Windows) ou
//     ~/.local/share/gescon (Linux/macOS), pasta 0700;
//   - na primeira execução gera a senha inicial do administrador (login
//     admin, troca obrigatória no primeiro acesso), grava em gescon.env
//     (0600) e mostra uma vez em PRIMEIRO-ACESSO.txt;
//   - sobe `advplc serve app/gescon.prw` em 127.0.0.1 (porta 8086 ou
//     GESCON_PORTA), com a saída num arquivo de log -- nunca em pipe: um
//     filho que herda o pipe trava o pai no Windows (lição do pacote GEBAN);
//   - se o GesCon já está no ar, só abre o navegador;
//   - `GesCon --encerrar` para o servidor desta instalação (PIDs em
//     gescon.pid na pasta de dados). O instalador e o desinstalador usam isto:
//     o NSIS é 32 bits e, num Windows 64 bits, não enxerga o caminho dos
//     processos de 64 bits (visto no Windows 10), então não dá para achá-los
//     por caminho.
package main

import (
	"bufio"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

func main() {
	if err := executar(); err != nil {
		avisar("GesCon não iniciou: " + err.Error())
		os.Exit(1)
	}
}

func executar() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	base := filepath.Dir(exe)
	dados, err := pastaDados()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dados, 0o700); err != nil {
		return err
	}
	pidArq := filepath.Join(dados, "gescon.pid")
	if len(os.Args) > 1 && os.Args[1] == "--encerrar" {
		encerrar(pidArq)
		return nil
	}
	envArq := filepath.Join(dados, "gescon.env")
	if _, err := os.Stat(envArq); os.IsNotExist(err) {
		if err := primeiroAcesso(dados, envArq); err != nil {
			return err
		}
	}
	env, err := lerEnv(envArq)
	if err != nil {
		return err
	}
	porta := env["GESCON_PORTA"]
	if porta == "" {
		porta = "8086"
	}
	url := "http://127.0.0.1:" + porta + "/"
	if noAr(url) {
		return abrir(url)
	}

	advplc := filepath.Join(base, "advplc")
	if runtime.GOOS == "windows" {
		advplc += ".exe"
	}
	log, err := os.OpenFile(filepath.Join(dados, "gescon.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	defer log.Close()
	cmd := exec.Command(advplc, "serve", filepath.Join(base, "app", "gescon.prw"),
		"--port", porta, "--db-path", filepath.Join(dados, "gescon.db"))
	cmd.Dir = dados
	cmd.Stdout, cmd.Stderr = log, log
	cmd.Env = append(os.Environ(), "ADVPL_SERVE_HOST=127.0.0.1", "ADVPP_WEBUI_HIDE_LOG=1")
	for k, v := range env {
		cmd.Env = append(cmd.Env, k+"="+v)
	}
	esconderJanela(cmd)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("não consegui executar %s: %w", advplc, err)
	}
	_ = os.WriteFile(pidArq, []byte(fmt.Sprintf("%d %d\n", cmd.Process.Pid, os.Getpid())), 0o600)
	defer os.Remove(pidArq)
	for i := 0; i < 150; i++ {
		if noAr(url) {
			_ = abrir(url)
			return cmd.Wait()
		}
		time.Sleep(200 * time.Millisecond)
	}
	_ = cmd.Process.Kill()
	return fmt.Errorf("o servidor não respondeu em 30 s (veja %s)", filepath.Join(dados, "gescon.log"))
}

// encerrar mata o servidor e o iniciador registrados em gescon.pid.
func encerrar(pidArq string) {
	b, err := os.ReadFile(pidArq)
	if err != nil {
		return
	}
	for _, campo := range strings.Fields(string(b)) {
		pid, err := strconv.Atoi(campo)
		if err != nil || pid == os.Getpid() {
			continue
		}
		if p, err := os.FindProcess(pid); err == nil {
			_ = p.Kill()
		}
	}
	_ = os.Remove(pidArq)
}

func pastaDados() (string, error) {
	if runtime.GOOS == "windows" {
		if d := os.Getenv("LOCALAPPDATA"); d != "" {
			return filepath.Join(d, "GesCon"), nil
		}
	}
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return filepath.Join(d, "gescon"), nil
	}
	h, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(h, ".local", "share", "gescon"), nil
}

// senhaInicial atende à política do GesCon (10+ caracteres, maiúscula,
// minúscula, número e especial): prefixo fixo "Gc#7" + 24 caracteres
// aleatórios (crypto/rand) sem os símbolos que atrapalham ao digitar.
func senhaInicial() (string, error) {
	b := make([]byte, 18)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	s := base64.RawURLEncoding.EncodeToString(b)
	s = strings.NewReplacer("-", "x", "_", "y").Replace(s)
	return "Gc#7" + s, nil
}

func primeiroAcesso(dados, envArq string) error {
	senha, err := senhaInicial()
	if err != nil {
		return err
	}
	conteudo := "# GesCon -- gerado na primeira execução. Senha inicial do administrador\n" +
		"# (só vale enquanto não houver usuário; o primeiro login pede uma senha nova).\n" +
		"GESCON_ADMIN_SENHA=" + senha + "\n" +
		"# Mala direta (descomente e preencha):\n" +
		"# GESCON_SMTP_HOST=smtp.exemplo.com\n# GESCON_SMTP_PORT=587\n# GESCON_SMTP_USER=usuario\n" +
		"# GESCON_SMTP_PASS=senha\n# GESCON_SMTP_FROM=gescon@seucondominio.com.br\n"
	if err := os.WriteFile(envArq, []byte(conteudo), 0o600); err != nil {
		return err
	}
	aviso := filepath.Join(dados, "PRIMEIRO-ACESSO.txt")
	texto := "GesCon -- primeiro acesso\r\n\r\n" +
		"Endereço: http://127.0.0.1:8086 (o GesCon abre sozinho no navegador)\r\n" +
		"Login: admin\r\nSenha inicial: " + senha + "\r\n\r\n" +
		"No primeiro login o GesCon pede uma senha nova. Depois disso, apague este arquivo.\r\n"
	if err := os.WriteFile(aviso, []byte(texto), 0o600); err != nil {
		return err
	}
	_ = abrir(aviso)
	return nil
}

func lerEnv(arq string) (map[string]string, error) {
	f, err := os.Open(arq)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	env := map[string]string{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		l := strings.TrimSpace(sc.Text())
		if l == "" || strings.HasPrefix(l, "#") {
			continue
		}
		if k, v, ok := strings.Cut(l, "="); ok {
			env[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	return env, sc.Err()
}

func noAr(url string) bool {
	c := http.Client{Timeout: 700 * time.Millisecond}
	r, err := c.Get(url)
	if err != nil {
		return false
	}
	r.Body.Close()
	return r.StatusCode == http.StatusOK
}

// abrir é variável para o teste não abrir arquivo nem navegador de verdade.
var abrir = func(alvo string) error {
	switch runtime.GOOS {
	case "windows":
		return exec.Command("rundll32", "url.dll,FileProtocolHandler", alvo).Start()
	case "darwin":
		return exec.Command("open", alvo).Start()
	default:
		return exec.Command("xdg-open", alvo).Start()
	}
}

func avisar(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	if runtime.GOOS == "windows" {
		_ = exec.Command("msg", "*", msg).Run()
	}
}
