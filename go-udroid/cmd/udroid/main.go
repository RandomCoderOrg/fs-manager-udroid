// Command udroid is the Go port of fs-manager-udroid — a proot wrapper
// for installing and running Linux rootfs containers on Termux/Android.
package main

import (
	"os"
)

func main() {
	if err := newRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}
