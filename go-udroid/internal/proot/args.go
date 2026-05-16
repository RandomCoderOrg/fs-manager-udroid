package proot

import (
	"errors"
	"io"
	"os"
	"path/filepath"
)

// BuildArgs is a pure transform from typed Options to the argv handed to
// `exec.Command("proot", ...)`.
//
// The function is intentionally a list of phase calls. Each phase appends
// a contiguous slice of args and has a single concern. Order matches bash
// udroid's final argv: termux/android binds, fake /proc binds, user binds,
// shared-tmp/shm, core /sys + /proc + /dev, session flags, --rootfs=,
// launcher. Matching bash here is load-bearing — proot's overlay handling
// is sensitive to where /proc gets bound relative to the fake /proc/<file>
// binds.
func BuildArgs(o Options) []string {
	a := make([]string, 0, 48)
	a = append(a, termuxBinds(o)...)
	a = append(a, fakeProcBinds(o)...)
	for _, b := range o.Binds {
		a = append(a, b.String())
	}
	a = append(a, sharedTmpBinds(o)...)
	a = append(a, coreBinds(o)...)
	a = append(a, sessionFlags(o)...)
	a = append(a, "--rootfs="+o.RootFS)
	a = append(a, buildLauncher(o)...)
	return a
}

// termuxBinds emits the host-side android paths the rootfs needs to see:
// /vendor, /system, $TERMUX_PREFIX, ld.config, /apex, /storage*, $HOME,
// termux app cache, and the dalvik cache. Skipped entirely when Isolated.
//
// Probes mirror bash udroid: stat for files, "ls -1U" semantics for
// directories that may exist-but-not-be-readable under selinux (e.g.
// /storage on locked-down devices).
func termuxBinds(o Options) []string {
	if !o.TermuxMounts || o.Isolated {
		return nil
	}
	pkg := o.AndroidPackage
	if pkg == "" {
		pkg = "com.termux"
	}
	var a []string
	for _, f := range []string{"/property_contexts", "/plat_property_contexts"} {
		if fileExists(f) {
			a = append(a, "--bind="+f)
		}
	}
	if fileExists("/vendor") {
		a = append(a, "--bind=/vendor")
	}
	if fileExists("/system") {
		a = append(a, "--bind=/system")
	}
	if o.HostPrefix != "" {
		a = append(a, "--bind="+o.HostPrefix)
	}
	if fileExists("/linkerconfig/ld.config.txt") {
		a = append(a, "--bind=/linkerconfig/ld.config.txt")
	}
	if fileExists("/apex") {
		a = append(a, "--bind=/apex")
	}
	if readableDir("/storage") {
		a = append(a, "--bind=/storage")
	}
	if bind := pickSharedStorage(); bind != "" {
		a = append(a, bind)
	}
	if o.HostHome != "" {
		a = append(a, "--bind="+o.HostHome)
	}
	if fileExists("/data/data/" + pkg + "/files/apps") {
		a = append(a, "--bind=/data/data/"+pkg+"/files/apps")
	}
	a = append(a,
		"--bind=/data/data/"+pkg+"/cache",
		"--bind=/data/dalvik-cache",
	)
	return a
}

// pickSharedStorage returns the first readable shared-storage path mapped
// to /sdcard inside the rootfs. Android exposes the same content under
// several mount points; whichever resolves first wins.
func pickSharedStorage() string {
	candidates := []struct{ src, dst string }{
		{"/storage/self/primary", "/sdcard"},
		{"/storage/emulated/0", "/sdcard"},
		{"/sdcard", "/sdcard"},
	}
	for _, c := range candidates {
		if fileExists(c.src) {
			return "--bind=" + c.src + ":" + c.dst
		}
	}
	return ""
}

// fakeProcBinds shadows kernel-provided /proc files with the static
// snapshots written by rootfs.ApplyFixes. Only emitted for files the host
// kernel won't let us read at runtime — bash udroid does the same, and
// stacking these on top of a working /proc/<name> confuses proot.
func fakeProcBinds(o Options) []string {
	if !o.FakeProcFiles {
		return nil
	}
	names := []string{"loadavg", "stat", "uptime", "version", "vmstat"}
	var a []string
	for _, name := range names {
		if hostProcReadable("/proc/" + name) {
			continue
		}
		src := filepath.Join(o.RootFS, "proc", "."+name)
		a = append(a, "--bind="+src+":/proc/"+name)
	}
	return a
}

// sharedTmpBinds bridges termux $PREFIX/tmp into /tmp and gives the rootfs
// a writable /dev/shm. When SharedTmp is off we fall back to reusing the
// rootfs's own /tmp as /dev/shm.
func sharedTmpBinds(o Options) []string {
	if o.SharedTmp && o.HostPrefix != "" {
		return []string{
			"--bind=" + o.RootFS + "/dev/shm:/dev/shm",
			"--bind=" + o.HostPrefix + "/tmp:/tmp",
		}
	}
	return []string{"--bind=" + o.RootFS + "/tmp:/dev/shm"}
}

// coreBinds wires up the always-needed kernel surfaces: /sys, the three
// std-fd-as-device tricks, /proc, /dev/random, /dev.
func coreBinds(o Options) []string {
	if !o.CoreMounts {
		return nil
	}
	return []string{
		"--bind=/sys",
		"--bind=/proc/self/fd/2:/dev/stderr",
		"--bind=/proc/self/fd/1:/dev/stdout",
		"--bind=/proc/self/fd/0:/dev/stdin",
		"--bind=/proc/self/fd:/dev/fd",
		"--bind=/proc",
		"--bind=/dev/urandom:/dev/random",
		"--bind=/dev",
	}
}

// sessionFlags emits the proot session toggles in bash's order:
// --root-id, cap_last_cap shim, --cwd, -L, kernel release, sysvipc,
// link2symlink, kill-on-exit, fix-low-ports, ashmem-memfd.
func sessionFlags(o Options) []string {
	var a []string
	if o.FakeRootID {
		a = append(a, "--root-id")
	}
	if o.CapLastCapFix {
		a = append(a, "--bind=/dev/null:/proc/sys/kernel/cap_last_cap")
	}
	if cwd := pickCWD(o); cwd != "" {
		a = append(a, "--cwd="+cwd)
	}
	if o.FollowSymlinks {
		a = append(a, "-L")
	}
	if o.KernelRelease != "" {
		a = append(a, "--kernel-release="+o.KernelRelease)
	}
	if o.SysVIPC {
		a = append(a, "--sysvipc")
	}
	if o.Link2Symlink {
		a = append(a, "--link2symlink")
	}
	if o.KillOnExit {
		a = append(a, "--kill-on-exit")
	}
	if o.FixLowPorts {
		a = append(a, "-p")
	}
	if o.AshmemMemfd {
		a = append(a, "--ashmem-memfd")
	}
	return a
}

// pickCWD resolves the working directory for the inner process. Explicit
// CWD wins; Isolated forces /root; otherwise inherit the host PWD so the
// user lands in the same directory they ran udroid from.
func pickCWD(o Options) string {
	switch {
	case o.CWD != "":
		return o.CWD
	case o.Isolated:
		return "/root"
	default:
		return o.HostPWD
	}
}

// readableDir returns true when path is a directory and the caller can
// actually enumerate it. Mirrors bash udroid's `ls -1U` probe — needed
// because Android selinux often makes /storage stattable but unreadable.
func readableDir(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	_, err = f.Readdirnames(1)
	return err == nil || errors.Is(err, io.EOF)
}

// hostProcReadable returns true when the kernel can satisfy a one-byte
// read of path. Used to decide whether a fake /proc/<name> bind is needed.
func hostProcReadable(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	buf := make([]byte, 1)
	_, err = f.Read(buf)
	return err == nil
}

// fileExists is a one-arg os.Stat error check, used heavily by the bind
// probes for paths that may legitimately be absent on some devices.
func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// buildLauncher returns the trailing `/usr/bin/env -i ... /bin/su -l user`
// piece. Shell selection mirrors bash udroid: prefer /bin/su, fall back
// to /bin/bash, then /bin/sh — probed against the host-side rootfs path
// before proot chroots so we never hand proot a launcher it can't exec.
func buildLauncher(o Options) []string {
	term := os.Getenv("TERM")
	if term == "" {
		term = "xterm-256color"
	}
	user := o.LoginUser
	if user == "" {
		user = "root"
	}
	env := []string{"/usr/bin/env", "-i", "HOME=/root", "LANG=C.UTF-8", "TERM=" + term}
	shell, useSu := pickShell(o.RootFS)
	cmd := launcherCommand(o)

	switch {
	case cmd != "" && useSu:
		return append(env, shell, "-l", user, "-c", cmd)
	case cmd != "":
		return append(env, shell, "-l", "-c", cmd)
	case useSu:
		return append(env, shell, "-l", user)
	default:
		return append(env, shell, "-l")
	}
}

// launcherCommand collapses RunScript and Command into the single `-c`
// argument the shell will run. Empty means interactive login.
func launcherCommand(o Options) string {
	if o.RunScript != "" {
		return "/" + filepath.Base(o.RunScript)
	}
	if len(o.Command) > 0 {
		return shellJoin(o.Command)
	}
	return ""
}

// pickShell returns the launcher binary to exec and whether to invoke it
// in su-style (passing the target user as a positional arg). Probes are
// done against the host-side rootfs path before proot chroots.
func pickShell(rootFS string) (path string, isSu bool) {
	if rootFS != "" {
		if fileExecutable(filepath.Join(rootFS, "bin/su")) {
			return "/bin/su", true
		}
		if fileExecutable(filepath.Join(rootFS, "bin/bash")) {
			return "/bin/bash", false
		}
	}
	return "/bin/sh", false
}

func fileExecutable(path string) bool {
	st, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !st.IsDir() && st.Mode()&0o111 != 0
}

// shellJoin quotes each token so the resulting string is safe to hand to
// `sh -c`. Conservative — wraps every token in single quotes and escapes
// embedded single quotes.
func shellJoin(parts []string) string {
	out := ""
	for i, p := range parts {
		if i > 0 {
			out += " "
		}
		out += "'" + escapeSingleQuote(p) + "'"
	}
	return out
}

func escapeSingleQuote(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] == '\'' {
			out = append(out, '\'', '\\', '\'', '\'')
			continue
		}
		out = append(out, s[i])
	}
	return string(out)
}
