//go:build windows

// Lançador do GesCon instalado. Só existe no pacote do instalador — o zip
// avulso continua sendo o executável direto.
//
// Faz duas coisas que o executável sozinho não tem como fazer:
//
//  1. Aponta ADVPP_DB para o banco COMPARTILHADO do condomínio. Desde o AdvPP
//     2.0.11 um app distribuído guarda o banco em %AppData%\advpp\<app>\, que
//     é por usuário do Windows — estável, e errado aqui: o banco é do
//     condomínio, não da conta de quem abriu. A variável fica no processo
//     filho; gravada no ambiente da máquina ela valeria para toda ferramenta
//     AdvPP e sequestraria também advplc, adveditor e advpp-ide.
//
//  2. Deixa o programa de verdade fora do caminho. Ele é instalado em
//     {app}\app\, então não há ícone clicável que pule este passo — que era
//     exatamente o furo do GesCon.cmd que este binário substitui.
//
// Compilado no subsistema GUI (-H=windowsgui): sem console, sem piscada de
// janela preta. O preço é não haver stderr visível, então falha aqui vira
// MessageBox — este programa nasceu para consertar um caso de "não abre e não
// diz nada", seria mau gosto reintroduzir o mesmo defeito.
package main

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

// bancoCompartilhado pode ser trocado no build com
// -ldflags "-X main.bancoCompartilhado=<caminho>".
var bancoCompartilhado = `C:\ProgramData\GesCon\GesCon.db`

// programa é relativo à pasta do lançador.
const programa = `app\GesConApp-windows-amd64.exe`

func main() {
	lancador, err := os.Executable()
	if err != nil {
		fatal("Não foi possível descobrir a própria localização.\n\n" + err.Error())
	}
	base := filepath.Dir(lancador)
	alvo := filepath.Join(base, programa)

	if _, err := os.Stat(alvo); err != nil {
		fatal("O programa não foi encontrado em:\n" + alvo +
			"\n\nA instalação parece incompleta. Reinstale o GesCon.")
	}

	ambiente := os.Environ()
	// ADVPP_DB já definida manda: quem apontou para outro banco de propósito
	// (banco de teste, pasta de rede) não pode ser sobrescrito pelo padrão.
	if os.Getenv("ADVPP_DB") == "" {
		pasta := filepath.Dir(bancoCompartilhado)
		if err := os.MkdirAll(pasta, 0o777); err != nil {
			fatal("Não foi possível criar a pasta do banco compartilhado:\n" + pasta +
				"\n\n" + err.Error())
		}
		ambiente = append(ambiente, "ADVPP_DB="+bancoCompartilhado)
	}

	// A saída do filho é capturada, não descartada. exec.Command sem Stdout
	// definido joga tudo fora, e foi assim que a primeira versão deste
	// lançador conseguiu produzir exatamente o silêncio que ela existia para
	// eliminar: o programa morria, escrevia o motivo, e ninguém via.
	var saida bytes.Buffer

	cmd := exec.Command(alvo, os.Args[1:]...)
	cmd.Env = ambiente
	cmd.Stdout = &saida
	cmd.Stderr = &saida
	// Diretório de trabalho na pasta do programa. O app não depende mais
	// disso desde o AdvPP 2.0.11, mas um diretório herdado de onde o atalho
	// foi clicado não serve para nada e só cria surpresa.
	cmd.Dir = filepath.Dir(alvo)

	if err := cmd.Start(); err != nil {
		fatal("Não foi possível iniciar o GesCon:\n" + alvo + "\n\n" + err.Error())
	}

	// Espera de propósito, apesar de custar um processo parado na memória: é
	// o que permite transformar "não abre e não diz nada" numa mensagem. Um
	// programa que falha no carregamento (DLL ausente, OpenGL indisponível)
	// morre em menos de um segundo e nunca chega a desenhar janela.
	err = cmd.Wait()
	if err == nil {
		return
	}

	relato := "O GesCon encerrou com erro.\n\n" +
		"Programa: " + alvo + "\n" +
		"Banco: " + os.Getenv("ADVPP_DB") + "\n" +
		"Código: " + err.Error() + "\n\n"
	if texto := strings.TrimSpace(saida.String()); texto != "" {
		relato += "Saída do programa:\n" + texto
	} else {
		relato += "O programa não escreveu nada. Encerrar sem mensagem, logo " +
			"depois de iniciar, costuma ser falha no carregamento de DLL — " +
			"no caso deste programa, quase sempre o OpenGL. Reinstale marcando " +
			"\"Renderização por software\"."
	}
	// Grava também em arquivo: a caixa de diálogo não dá para copiar direito,
	// e um relato que não pode ser colado numa conversa não ajuda ninguém.
	if log := filepath.Join(filepath.Dir(bancoCompartilhado), "gescon-erro.txt"); log != "" {
		_ = os.WriteFile(log, []byte(relato), 0o666)
		relato += "\n\n(Também gravado em " + log + ")"
	}
	fatal(relato)
}

// fatal mostra uma caixa de diálogo do Windows e encerra. Chamada por
// syscall porque o binário é puro Go, sem CGO — assim ele cross-compila de
// qualquer plataforma, ao contrário do executável principal, que arrasta o
// Fyne.
func fatal(msg string) {
	const mbIconError = 0x10
	titulo, err1 := syscall.UTF16PtrFromString("GesCon")
	texto, err2 := syscall.UTF16PtrFromString(msg)
	if err1 == nil && err2 == nil {
		proc := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW")
		proc.Call(0, uintptr(unsafe.Pointer(texto)), uintptr(unsafe.Pointer(titulo)), mbIconError)
	}
	os.Exit(1)
}
