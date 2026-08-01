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

	saida, err := roda(alvo, ambiente)
	if err == nil {
		return
	}

	// Primeira falha: se o motivo for OpenGL indisponível, instala o Mesa3D
	// ao lado do programa e tenta de novo.
	//
	// Isto vive aqui, e não no instalador, porque o instalador não tem como
	// saber. Adivinhar pelo registro se a máquina tem driver de vídeo já
	// errou — numa VM QXL o driver está registrado e OpenGL não existe. E o
	// erro não é simétrico: instalar o Mesa onde ele não funciona derruba o
	// programa no carregador, sem janela nem mensagem, enquanto não instalar
	// onde ele é necessário dá um erro legível na tela. Em execução não há
	// adivinhação: ou o programa abriu, ou disse por que não.
	if semOpenGL(saida) && instalaMesa(filepath.Dir(alvo)) == nil {
		if saida, err = roda(alvo, ambiente); err == nil {
			return
		}
	}

	relata(alvo, saida, err)
}

// roda executa o programa e devolve o que ele escreveu.
//
// A saída é capturada, não descartada: exec.Command sem Stdout definido joga
// tudo fora, e foi assim que a primeira versão deste lançador produziu
// exatamente o silêncio que ela existia para eliminar.
//
// Espera o fim de propósito, apesar de deixar um processo parado na memória.
// É o que permite transformar "não abre e não diz nada" numa mensagem: quem
// falha no carregamento morre em menos de um segundo, sem nunca desenhar
// janela.
func roda(alvo string, ambiente []string) (string, error) {
	var buf bytes.Buffer
	cmd := exec.Command(alvo, os.Args[1:]...)
	cmd.Env = ambiente
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	// Diretório de trabalho na pasta do programa. O app não depende mais
	// disso desde o AdvPP 2.0.11, mas um diretório herdado de onde o atalho
	// foi clicado não serve para nada e só cria surpresa.
	cmd.Dir = filepath.Dir(alvo)

	if err := cmd.Start(); err != nil {
		fatal("Não foi possível iniciar o GesCon:\n" + alvo + "\n\n" + err.Error())
	}
	err := cmd.Wait()
	return buf.String(), err
}

// semOpenGL reconhece a falha de criação de janela do Fyne por falta de
// OpenGL. Casa com o texto do glfw, não com o código de saída: o Fyne mostra
// a própria caixa de erro e encerra, e o código não distingue esse caso de
// qualquer outro.
func semOpenGL(saida string) bool {
	s := strings.ToLower(saida)
	return strings.Contains(s, "wgl") ||
		strings.Contains(s, "window creation error") ||
		strings.Contains(s, "apiunavailable")
}

// instalaMesa copia o Mesa3D de mesa/ para junto do programa, fazendo-o
// desenhar por software na CPU.
//
// A cópia é necessária porque opengl32.dll é import estático do executável:
// o Windows resolve pelo diretório do .exe antes do System32, e não há como
// redirecionar isso de fora depois que o processo começa. O instalador deixa
// esta pasta gravável para o usuário comum justamente por causa desta função.
func instalaMesa(pastaPrograma string) error {
	origem := filepath.Join(filepath.Dir(pastaPrograma), "mesa")
	for _, nome := range []string{"opengl32.dll", "libgallium_wgl.dll"} {
		dados, err := os.ReadFile(filepath.Join(origem, nome))
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(pastaPrograma, nome), dados, 0o666); err != nil {
			return err
		}
	}
	return nil
}

// relata mostra a falha e a grava em arquivo. Caixa de diálogo não dá para
// copiar direito, e relato que não pode ser colado numa conversa não ajuda.
func relata(alvo, saida string, err error) {
	texto := "O GesCon encerrou com erro.\n\n" +
		"Programa: " + alvo + "\n" +
		"Banco: " + os.Getenv("ADVPP_DB") + "\n" +
		"Código: " + err.Error() + "\n\n"
	if s := strings.TrimSpace(saida); s != "" {
		texto += "Saída do programa:\n" + s
	} else {
		texto += "O programa não escreveu nada. Encerrar sem mensagem, logo " +
			"depois de iniciar, costuma ser falha no carregamento de DLL. Se " +
			"a pasta app\\ tiver opengl32.dll e libgallium_wgl.dll, apague os " +
			"dois: o Mesa3D não funciona em toda máquina, e nessas ele mata o " +
			"processo antes de qualquer mensagem."
	}
	if log := filepath.Join(filepath.Dir(bancoCompartilhado), "gescon-erro.txt"); log != "" {
		_ = os.WriteFile(log, []byte(texto), 0o666)
		texto += "\n\n(Também gravado em " + log + ")"
	}
	fatal(texto)
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
