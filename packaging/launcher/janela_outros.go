//go:build !windows

package main

import "os/exec"

func esconderJanela(cmd *exec.Cmd) {}
