package proot

import (
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
