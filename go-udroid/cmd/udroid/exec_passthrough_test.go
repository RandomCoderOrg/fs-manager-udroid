package main

import (
	"bytes"
	"errors"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

// TestExecForwardsDashFlags pins the SetInterspersed(false) contract:
// dash-prefixed tokens after the rootfs name must reach RunE intact rather
// than being parsed as flags on `exec` itself. The test runs only the
// arg-parsing layer — no proot, no filesystem — by replacing RunE with a
// captor.
func TestExecForwardsDashFlags(t *testing.T) {
	var captured []string
	cmd := &cobra.Command{
		Use: "exec [flags] <name> <cmd> [args...]",
		RunE: func(_ *cobra.Command, args []string) error {
			captured = args
			return errors.New("stop") // bail out so cobra doesn't run anything
		},
	}
	var user string
	cmd.Flags().StringVarP(&user, "user", "u", "", "user")
	cmd.Flags().SetInterspersed(false)

	root := &cobra.Command{Use: "udroid"}
	root.AddCommand(cmd)
	root.SetArgs([]string{"exec", "ubuntu-jammy", "ls", "-la", "/tmp"})
	root.SetOut(&bytes.Buffer{})
	root.SetErr(&bytes.Buffer{})
	_ = root.Execute()

	want := []string{"ubuntu-jammy", "ls", "-la", "/tmp"}
	if strings.Join(captured, "|") != strings.Join(want, "|") {
		t.Fatalf("dash flags swallowed: got %q, want %q", captured, want)
	}

	// And the -u flag still works when placed before the positionals.
	user = ""
	captured = nil
	root.SetArgs([]string{"exec", "-u", "alice", "ubuntu-jammy", "env"})
	_ = root.Execute()
	if user != "alice" {
		t.Fatalf("--user not parsed: got %q", user)
	}
	if strings.Join(captured, "|") != "ubuntu-jammy|env" {
		t.Fatalf("positional capture wrong: got %q", captured)
	}
}
