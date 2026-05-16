package proot

import (
	"os"
	"path/filepath"
)

// BuildArgs is a pure transform from typed Options to the argv that gets
// handed to exec.Command("proot", ...).
//
// Order of args matters to proot in some cases (notably the trailing
// program + its argv comes last); see comments at each section.
//
// Determinism: same Options always produces the same argv. No env reads,
// no time, no random ordering, which keeps the output testable.
func BuildArgs(o Options) []string {
	var a []string

	// --- session-scoped flags --------------------------------------------------
	if o.FixLowPorts {
		a = append(a, "-p")
	}
	if o.AshmemMemfd {
		a = append(a, "--ashmem-memfd")
	}
	if o.KillOnExit {
		a = append(a, "--kill-on-exit")
	}
	if o.Link2Symlink {
		a = append(a, "--link2symlink")
	}
	if o.SysVIPC {
		a = append(a, "--sysvipc")
	}
	if o.FakeRootID {
		a = append(a, "--root-id")
	}
	if o.KernelRelease != "" {
		a = append(a, "--kernel-release="+o.KernelRelease)
	}
	if o.FollowSymlinks {
		a = append(a, "-L")
	}
	if o.CWD != "" {
		a = append(a, "--cwd="+o.CWD)
	}

	// --- core mounts -----------------------------------------------------------
	if o.CoreMounts {
		a = append(a,
			"--bind=/dev",
			"--bind=/dev/urandom:/dev/random",
			"--bind=/proc",
			"--bind=/proc/self/fd:/dev/fd",
			"--bind=/proc/self/fd/0:/dev/stdin",
			"--bind=/proc/self/fd/1:/dev/stdout",
			"--bind=/proc/self/fd/2:/dev/stderr",
			"--bind=/sys",
		)
	}

	if o.CapLastCapFix {
		a = append(a, "--bind=/dev/null:/proc/sys/kernel/cap_last_cap")
	}

	if o.SharedTmp && o.HostPrefix != "" {
		a = append(a,
			"--bind="+o.HostPrefix+"/tmp:/tmp",
			"--bind="+o.RootFS+"/dev/shm:/dev/shm",
		)
	} else {
		a = append(a, "--bind="+o.RootFS+"/tmp:/dev/shm")
	}

	// --- fake /proc/* (used when the host blocks reading those files) ---------
	if o.FakeProcFiles {
		for _, rel := range []string{"loadavg", "stat", "uptime", "version", "vmstat"} {
			a = append(a, "--bind="+filepath.Join(o.RootFS, "proc", "."+rel)+":/proc/"+rel)
		}
	}

	// --- user binds (after core so they can override) ------------------------
	for _, b := range o.Binds {
		a = append(a, b.String())
	}

	// --- termux + android paths -----------------------------------------------
	if o.TermuxMounts && !o.Isolated {
		pkg := o.AndroidPackage
		if pkg == "" {
			pkg = "com.termux"
		}
		a = append(a,
			"--bind=/data/dalvik-cache",
			"--bind=/data/data/"+pkg+"/cache",
		)
		if _, err := os.Stat("/data/data/" + pkg + "/files/apps"); err == nil {
			a = append(a, "--bind=/data/data/"+pkg+"/files/apps")
		}
		if o.HostHome != "" {
			a = append(a, "--bind="+o.HostHome)
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
		if _, err := os.Stat("/storage"); err == nil {
			a = append(a, "--bind=/storage")
		}
		if _, err := os.Stat("/apex"); err == nil {
			a = append(a, "--bind=/apex")
		}
		if _, err := os.Stat("/linkerconfig/ld.config.txt"); err == nil {
			a = append(a, "--bind=/linkerconfig/ld.config.txt")
		}
		if o.HostPrefix != "" {
			a = append(a, "--bind="+o.HostPrefix)
		}
		if _, err := os.Stat("/system"); err == nil {
			a = append(a, "--bind=/system")
		}
		if _, err := os.Stat("/vendor"); err == nil {
			a = append(a, "--bind=/vendor")
		}
		for _, f := range []string{"/plat_property_contexts", "/property_contexts"} {
			if _, err := os.Stat(f); err == nil {
				a = append(a, "--bind="+f)
			}
		}
	}

	// --- rootfs (must come after binds) --------------------------------------
	a = append(a, "--rootfs="+o.RootFS)

	// --- shell launcher -------------------------------------------------------
	a = append(a, buildLauncher(o)...)
	return a
}

// buildLauncher returns the trailing `/usr/bin/env -i HOME=... su -l user -c "..."`
// piece. Split out so unit tests can exercise it without the bind stew above.
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

	// run-script overrides Command
	if o.RunScript != "" {
		return append(env, "/bin/su", "-l", user, "-c", "/"+filepath.Base(o.RunScript))
	}
	if len(o.Command) > 0 {
		joined := shellJoin(o.Command)
		return append(env, "/bin/su", "-l", user, "-c", joined)
	}
	return append(env, "/bin/su", "-l", user)
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
