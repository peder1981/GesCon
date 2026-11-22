//go:build windows

package main

import (
	"os/exec"
	"syscall"
)

// esconderJanela: o advplc é programa de console; sem isto abriria uma janela
// preta atrás do navegador.
func esconderJanela(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
}
