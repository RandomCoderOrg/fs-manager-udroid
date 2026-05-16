package proot

import (
	"errors"
	"io"
	"os"
	"path/filepath"
)

// BuildArgs is a pure transform from typed Options to the argv that gets
// handed to exec.Command("proot", ...).
//
// The argv layout mirrors bash udroid's final order verbatim so we don't
// trip on any subtle proot ordering behaviour: termux/android binds first,
// conditional fake /proc binds, custom binds, shared-tmp + core /proc + /sys,
// /dev binds, then the session flags, --rootfs=, and finally the launcher.
//
// Determinism: same Options always produces the same argv. The only
// non-deterministic inputs are os.Stat probes for paths that may or may
// not exist on the host (e.g. /apex, /vendor), which is intentional —
// the bash version probes the same way.
func BuildArgs(o Options) []string {
	a := make([]string, 0, 48)

	// --- termux + android paths (must precede /proc bind below so a later
	//     --bind=/proc takes precedence on overlap) ---------------------------
	if o.TermuxMounts && !o.Isolated {
		pkg := o.AndroidPackage
		if pkg == "" {
			pkg = "com.termux"
		}
		for _, f := range []string{"/property_contexts", "/plat_property_contexts"} {
			if _, err := os.Stat(f); err == nil {
				a = append(a, "--bind="+f)
			}
		}
		if _, err := os.Stat("/vendor"); err == nil {
			a = append(a, "--bind=/vendor")
		}
		if _, err := os.Stat("/system"); err == nil {
			a = append(a, "--bind=/system")
		}
		if o.HostPrefix != "" {
			a = append(a, "--bind="+o.HostPrefix)
		}
		if _, err := os.Stat("/linkerconfig/ld.config.txt"); err == nil {
			a = append(a, "--bind=/linkerconfig/ld.config.txt")
		}
		if _, err := os.Stat("/apex"); err == nil {
			a = append(a, "--bind=/apex")
		}
		// bash udroid probes /storage with `ls -1U /storage`, which fails
		// when the directory exists but isn't readable (Android selinux
		// often forbids reads even when the path stats). os.Stat would
		// add the bind unconditionally; readableDir matches bash and
		// avoids a stray --bind that bash never emits.
		if readableDir("/storage") {
			a = append(a, "--bind=/storage")
		}
		// shared storage probes — pick the first that resolves
		for _, candidate := range []struct{ src, dst string }{
			{"/storage/self/primary", "/sdcard"},
			{"/storage/emulated/0", "/sdcard"},
			{"/sdcard", "/sdcard"},
		} {
			if _, err := os.Stat(candidate.src); err == nil {
				a = append(a, "--bind="+candidate.src+":"+candidate.dst)
				break
			}
		}
		if o.HostHome != "" {
			a = append(a, "--bind="+o.HostHome)
		}
		if _, err := os.Stat("/data/data/" + pkg + "/files/apps"); err == nil {
			a = append(a, "--bind=/data/data/"+pkg+"/files/apps")
		}
		a = append(a,
			"--bind=/data/data/"+pkg+"/cache",
			"--bind=/data/dalvik-cache",
		)
	}

	// --- fake /proc/* binds: only when host's real /proc/<name> is
	// unreadable. Adding them on top of an already-bound /proc confuses
	// proot's overlay handling — matching bash here is load-bearing.
	if o.FakeProcFiles {
		for _, rel := range []string{"loadavg", "stat", "uptime", "version", "vmstat"} {
			if !hostProcReadable("/proc/" + rel) {
				a = append(a, "--bind="+filepath.Join(o.RootFS, "proc", "."+rel)+":/proc/"+rel)
			}
		}
	}

	// --- user binds + per-fs binds --------------------------------------------
	for _, b := range o.Binds {
		a = append(a, b.String())
	}

	// --- shared tmp / shm -----------------------------------------------------
	if o.SharedTmp && o.HostPrefix != "" {
		a = append(a,
			"--bind="+o.RootFS+"/dev/shm:/dev/shm",
			"--bind="+o.HostPrefix+"/tmp:/tmp",
		)
	} else {
		a = append(a, "--bind="+o.RootFS+"/tmp:/dev/shm")
	}

	// --- core mounts ----------------------------------------------------------
	if o.CoreMounts {
		a = append(a,
			"--bind=/sys",
			"--bind=/proc/self/fd/2:/dev/stderr",
			"--bind=/proc/self/fd/1:/dev/stdout",
			"--bind=/proc/self/fd/0:/dev/stdin",
			"--bind=/proc/self/fd:/dev/fd",
			"--bind=/proc",
			"--bind=/dev/urandom:/dev/random",
			"--bind=/dev",
		)
	}

	// --- session toggles + flags ----------------------------------------------
	if o.FakeRootID {
		a = append(a, "--root-id")
	}
	if o.CapLastCapFix {
		a = append(a, "--bind=/dev/null:/proc/sys/kernel/cap_last_cap")
	}
	switch {
	case o.CWD != "":
		a = append(a, "--cwd="+o.CWD)
	case o.Isolated:
		a = append(a, "--cwd=/root")
	case o.HostPWD != "":
		a = append(a, "--cwd="+o.HostPWD)
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

	// --- rootfs (must come immediately before the launcher) ------------------
	a = append(a, "--rootfs="+o.RootFS)

	// --- shell launcher -------------------------------------------------------
	a = append(a, buildLauncher(o)...)
	return a
}

// readableDir returns true when path is a directory and the caller can
// actually enumerate it. Mirrors bash udroid's `ls -1U` probe.
func readableDir(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	_, err = f.Readdirnames(1)
	return err == nil || errors.Is(err, io.EOF)
}

// hostProcReadable returns true when the kernel can satisfy a read of path.
// Used to decide whether a fake /proc/<name> bind is needed.
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

// buildLauncher returns the trailing `/usr/bin/env -i HOME=... su -l user -c "..."`
// piece. Split out so unit tests can exercise it without the bind stew above.
//
// Shell selection mirrors bash udroid: prefer /bin/su (with -l), fall back
// to /bin/bash, then /bin/sh. The probe is done against the host-side
// rootfs path so we never hand proot a launcher it can't exec.
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

	if o.RunScript != "" {
		script := "/" + filepath.Base(o.RunScript)
		if useSu {
			return append(env, shell, "-l", user, "-c", script)
		}
		return append(env, shell, "-l", "-c", script)
	}
	if len(o.Command) > 0 {
		joined := shellJoin(o.Command)
		if useSu {
			return append(env, shell, "-l", user, "-c", joined)
		}
		return append(env, shell, "-l", "-c", joined)
	}
	if useSu {
		return append(env, shell, "-l", user)
	}
	return append(env, shell, "-l")
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
// `su -c`. Conservative — wraps every token in single quotes and escapes
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
