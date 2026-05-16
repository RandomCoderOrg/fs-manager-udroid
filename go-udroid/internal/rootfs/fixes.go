// Package rootfs handles all on-disk filesystem operations for an installed
// container: downloading the tarball, verifying it, applying the proot
// post-extraction fixes, and removing it again.
package rootfs

import (
	_ "embed"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
	"strings"
)

//go:embed embed/proc_stat.txt
var procStat []byte

//go:embed embed/proc_vmstat.txt
var procVmstat []byte

//go:embed embed/proc_version.txt
var procVersion []byte

//go:embed embed/proc_uptime.txt
var procUptime []byte

//go:embed embed/proc_loadavg.txt
var procLoadavg []byte

//go:embed embed/hosts
var etcHosts []byte

//go:embed embed/resolv.conf
var etcResolv []byte

// FixesOptions tunes ApplyFixes. Zero value is fine for normal use.
type FixesOptions struct {
	// TermuxPrefix is interpolated into the profile snippet as TERMUX_PREFIX.
	// When empty the literal "@TERMUX_PREFIX@" is left in place so an
	// upgrade pass can resolve it later.
	TermuxPrefix string

	// AndroidGroups maps android group names to GIDs. Each becomes an
	// `aid_<name>:x:<gid>:root,aid_<user>` entry in /etc/group so apps
	// inside the container can interact with host services. Pass the
	// result of HostAndroidGroups() to mirror the host.
	AndroidGroups []AndroidGroup

	// LoginUser is interpolated into the aid_<user> group member. Defaults
	// to the current OS user.
	LoginUser string
}

// AndroidGroup is one host android GID entry.
type AndroidGroup struct {
	Name string
	GID  int
}

// ApplyFixes mirrors proot-fixes.sh — writes fake /proc/* files inside the
// rootfs, populates /etc/hosts and /etc/resolv.conf, appends an env-export
// snippet to /etc/profile, and registers android aid_* groups.
//
// Idempotency: writes to /proc/.* and /etc/hosts/resolv.conf overwrite,
// /etc/profile additions are appended every time the function is run, so
// callers should only invoke this once per install (or use --reinstall-fixes
// after manually editing /etc/profile).
func ApplyFixes(rootFS string, opts FixesOptions) error {
	st, err := os.Stat(rootFS)
	if err != nil {
		return fmt.Errorf("rootfs %q: %w", rootFS, err)
	}
	if !st.IsDir() {
		return fmt.Errorf("rootfs %q is not a directory", rootFS)
	}

	for _, d := range []string{"dev", "sys", "proc", "etc", "dev/shm"} {
		if err := os.MkdirAll(filepath.Join(rootFS, d), 0o755); err != nil {
			return err
		}
	}
	if err := os.Chmod(filepath.Join(rootFS, "proc"), 0o700); err != nil {
		return err
	}

	files := map[string][]byte{
		"proc/.version":    procVersion,
		"proc/.uptime":     procUptime,
		"proc/.stat":       procStat,
		"proc/.loadavg":    procLoadavg,
		"proc/.vmstat":     procVmstat,
		"etc/hosts":        etcHosts,
		"etc/resolv.conf":  etcResolv,
	}
	for rel, body := range files {
		if err := writeFile(filepath.Join(rootFS, rel), body, 0o644); err != nil {
			return err
		}
	}

	if err := appendProfile(rootFS, opts); err != nil {
		return err
	}
	if err := appendAndroidGroups(rootFS, opts); err != nil {
		return err
	}

	// sudo setuid — best-effort; some rootfs variants ship without sudo.
	_ = os.Chmod(filepath.Join(rootFS, "usr/bin/sudo"), 0o4755)

	// Strip zsh-completion compdump files that get baked in during build.
	matches, _ := filepath.Glob(filepath.Join(rootFS, "root", ".zcom*"))
	for _, m := range matches {
		_ = os.RemoveAll(m)
	}
	return nil
}

func writeFile(path string, body []byte, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, body, mode)
}

func appendProfile(rootFS string, opts FixesOptions) error {
	target := filepath.Join(rootFS, "etc/profile.d/udroid.sh")
	if _, err := os.Stat(filepath.Join(rootFS, "etc/profile.d")); err != nil {
		// no profile.d — fall back to /etc/profile like the bash version
		target = filepath.Join(rootFS, "etc/profile")
		_ = os.Chmod(target, 0o755)
	}
	prefix := opts.TermuxPrefix
	if prefix == "" {
		prefix = "@TERMUX_PREFIX@"
	}
	snippet := `export ANDROID_ART_ROOT=${ANDROID_ART_ROOT-}
export ANDROID_DATA=${ANDROID_DATA-}
export ANDROID_I18N_ROOT=${ANDROID_I18N_ROOT-}
export ANDROID_ROOT=${ANDROID_ROOT-}
export ANDROID_RUNTIME_ROOT=${ANDROID_RUNTIME_ROOT-}
export ANDROID_TZDATA_ROOT=${ANDROID_TZDATA_ROOT-}
export TERMUX_PREFIX=` + prefix + `
export BOOTCLASSPATH=${BOOTCLASSPATH-}
export COLORTERM=${COLORTERM-}
export DEX2OATBOOTCLASSPATH=${DEX2OATBOOTCLASSPATH-}
export EXTERNAL_STORAGE=${EXTERNAL_STORAGE-}
[ -z "$LANG" ] && export LANG=C.UTF-8
export PATH=${PATH}:` + prefix + `/bin:/system/bin:/system/xbin
export TERM=${TERM-xterm-256color}
export TMPDIR=/tmp
export PULSE_SERVER=127.0.0.1
export MOZ_FAKE_NO_SANDBOX=1
`
	f, err := os.OpenFile(target, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(snippet)
	return err
}

func appendAndroidGroups(rootFS string, opts FixesOptions) error {
	if len(opts.AndroidGroups) == 0 {
		return nil
	}
	loginUser := opts.LoginUser
	if loginUser == "" {
		if u, err := user.Current(); err == nil {
			loginUser = u.Username
		} else {
			loginUser = "termux"
		}
	}
	groupPath := filepath.Join(rootFS, "etc/group")
	gshadowPath := filepath.Join(rootFS, "etc/gshadow")
	hasGshadow := fileExists(gshadowPath)

	var gb, sb strings.Builder
	for _, g := range opts.AndroidGroups {
		fmt.Fprintf(&gb, "aid_%s:x:%d:root,aid_%s\n", g.Name, g.GID, loginUser)
		if hasGshadow {
			fmt.Fprintf(&sb, "aid_%s:*::root,aid_%s\n", g.Name, loginUser)
		}
	}
	if err := appendString(groupPath, gb.String()); err != nil {
		return err
	}
	if hasGshadow {
		if err := appendString(gshadowPath, sb.String()); err != nil {
			return err
		}
	}
	return nil
}

func appendString(path, s string) error {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(s)
	return err
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
