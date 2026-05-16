package proot

import (
	"os"
	"strings"
	"testing"
)

// TestBuildArgs_BaseFlagsPresent locks in that the defaults emit the
// session-scoped flags every login depends on (kill-on-exit, link2symlink,
// sysvipc, root-id, fake kernel release).
func TestBuildArgs_BaseFlagsPresent(t *testing.T) {
	o := DefaultOptions("/tmp/does-not-matter-for-args")
	o.HostPrefix = "/data/data/com.termux/files/usr"
	o.HostHome = "/data/data/com.termux/files/home"
	got := strings.Join(BuildArgs(o), " ")
	for _, want := range []string{
		"--kill-on-exit",
		"--link2symlink",
		"--sysvipc",
		"--root-id",
		"--kernel-release=5.4.2-proot-facked",
		"-L",
		"--rootfs=/tmp/does-not-matter-for-args",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("expected flag %q in argv, got:\n%s", want, got)
		}
	}
}

// TestBuildArgs_NoFlagsDisableFeatures ensures the --no-* toggles in the
// CLI drop the corresponding proot flag entirely (rather than emitting
// some "--no-link2symlink" pseudo-flag, which proot wouldn't understand).
func TestBuildArgs_NoFlagsDisableFeatures(t *testing.T) {
	o := DefaultOptions("/x")
	o.Link2Symlink = false
	o.SysVIPC = false
	o.KillOnExit = false
	got := strings.Join(BuildArgs(o), " ")
	for _, banned := range []string{"--link2symlink", "--sysvipc", "--kill-on-exit"} {
		if strings.Contains(got, banned) {
			t.Errorf("flag %q should be absent, got:\n%s", banned, got)
		}
	}
}

// TestBuildArgs_RootfsLast verifies that --rootfs precedes the launcher
// but follows the user binds; proot processes mounts in order so
// reordering can break overlay semantics.
func TestBuildArgs_RootfsLast(t *testing.T) {
	o := DefaultOptions("/x")
	o.Binds = []Bind{{Source: "/host/data", Target: "/data"}}
	args := BuildArgs(o)
	rootfsIdx, bindIdx, launcherIdx := -1, -1, -1
	for i, a := range args {
		if a == "--rootfs=/x" {
			rootfsIdx = i
		}
		if a == "--bind=/host/data:/data" {
			bindIdx = i
		}
		if a == "/usr/bin/env" {
			launcherIdx = i
		}
	}
	if rootfsIdx < 0 || bindIdx < 0 || launcherIdx < 0 {
		t.Fatalf("missing markers: rootfs=%d bind=%d launcher=%d in %v", rootfsIdx, bindIdx, launcherIdx, args)
	}
	if !(bindIdx < rootfsIdx && rootfsIdx < launcherIdx) {
		t.Errorf("expected bind(%d) < rootfs(%d) < launcher(%d)", bindIdx, rootfsIdx, launcherIdx)
	}
}

// TestBuildArgs_CommandIsQuoted ensures embedded single-quotes in a
// passthrough command don't escape the shell wrapper.
func TestBuildArgs_CommandIsQuoted(t *testing.T) {
	o := DefaultOptions("/x")
	o.Command = []string{"echo", "it's fine"}
	args := BuildArgs(o)
	last := args[len(args)-1]
	if !strings.Contains(last, `'echo' 'it'\''s fine'`) {
		t.Errorf("expected escaped command, got %q", last)
	}
}

func TestBuildArgs_IsolatedSkipsTermuxBinds(t *testing.T) {
	o := DefaultOptions("/x")
	o.HostPrefix = "/usr"
	o.HostHome = "/home/u"
	o.Isolated = true
	got := strings.Join(BuildArgs(o), " ")
	if strings.Contains(got, "/home/u") {
		t.Errorf("isolated should not mount HostHome, got:\n%s", got)
	}
}

// TestBuildArgs_ShellFallback verifies the launcher falls back to
// /bin/bash and then /bin/sh when /bin/su is absent inside the rootfs.
// Catches regressions where a rootfs without su would fail outright.
func TestBuildArgs_ShellFallback(t *testing.T) {
	dir := t.TempDir()
	mustMkdir(t, dir+"/bin")
	// no su, no bash → /bin/sh
	args := BuildArgs(DefaultOptions(dir))
	if got := args[len(args)-2]; got != "/bin/sh" {
		t.Errorf("expected /bin/sh fallback, got %q (full: %v)", got, args[len(args)-3:])
	}
	// add bash → /bin/bash
	mustWriteExec(t, dir+"/bin/bash")
	args = BuildArgs(DefaultOptions(dir))
	if got := args[len(args)-2]; got != "/bin/bash" {
		t.Errorf("expected /bin/bash with no su, got %q", got)
	}
	// add su → /bin/su (with user arg)
	mustWriteExec(t, dir+"/bin/su")
	args = BuildArgs(DefaultOptions(dir))
	if got := args[len(args)-3]; got != "/bin/su" {
		t.Errorf("expected /bin/su when present, got %q", got)
	}
}

// TestBuildArgs_FakeProcSkippedWhenHostReadable: on a host where
// /proc/loadavg is readable (every linux + macOS dev box), the fake
// /proc bind for it must not be emitted. Bash udroid skips them under
// the same condition; stacking the fake on a working /proc bind throws
// proot off and was the cause of /bin/su misexec on first port.
func TestBuildArgs_FakeProcSkippedWhenHostReadable(t *testing.T) {
	if _, err := os.Stat("/proc/loadavg"); err != nil {
		t.Skip("host has no /proc/loadavg — test would be vacuous")
	}
	o := DefaultOptions("/x")
	got := strings.Join(BuildArgs(o), " ")
	if strings.Contains(got, "proc/.loadavg:/proc/loadavg") {
		t.Errorf("fake /proc/loadavg bind should be skipped when host /proc/loadavg is readable; got:\n%s", got)
	}
}

func mustMkdir(t *testing.T, p string) {
	t.Helper()
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatal(err)
	}
}

func mustWriteExec(t *testing.T, p string) {
	t.Helper()
	if err := os.WriteFile(p, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
}
