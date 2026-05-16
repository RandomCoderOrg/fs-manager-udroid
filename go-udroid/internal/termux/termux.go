// Package termux centralises path conventions and architecture detection
// for the Termux/Android host. All paths are derived from the standard
// Termux prefix and can be overridden via environment variables, making
// the tool usable on regular Linux for testing.
package termux

import (
	"os"
	"path/filepath"
	"runtime"
)

const (
	DefaultPackage = "com.termux"
	envPrefix      = "TERMUX_PREFIX"
	envHome        = "TERMUX_HOME"
	envPackage     = "TERMUX_APP_PACKAGE"
)

// Paths captures every directory the tool reads from or writes to. A single
// value of this type is constructed once at startup and passed around so
// nothing else has to know about Termux layout details.
type Paths struct {
	Package           string // android package name (com.termux)
	Prefix            string // /data/data/com.termux/files/usr
	Home              string // /data/data/com.termux/files/home
	Root              string // ${Prefix}/var/lib/udroid
	InstalledFsDir    string // ${Root}/installed-filesystems
	DownloadCache     string // ${Root}/dlcache
	RuntimeRoot       string // ${Prefix}/etc/udroid
	RuntimeCache      string // ${RuntimeRoot}/.cache
}

// DefaultPaths builds the canonical layout with env-var overrides applied.
func DefaultPaths() Paths {
	pkg := envOr(envPackage, DefaultPackage)
	prefix := envOr(envPrefix, "/data/data/"+pkg+"/files/usr")
	home := envOr(envHome, "/data/data/"+pkg+"/files/home")
	root := filepath.Join(prefix, "var", "lib", "udroid")
	rtRoot := filepath.Join(prefix, "etc", "udroid")
	return Paths{
		Package:        pkg,
		Prefix:         prefix,
		Home:           home,
		Root:           root,
		InstalledFsDir: filepath.Join(root, "installed-filesystems"),
		DownloadCache:  filepath.Join(root, "dlcache"),
		RuntimeRoot:    rtRoot,
		RuntimeCache:   filepath.Join(rtRoot, ".cache"),
	}
}

// EnsureWritable creates the directories the tool needs at runtime.
// Idempotent — safe to call on every invocation.
func (p Paths) EnsureWritable() error {
	for _, d := range []string{p.Root, p.InstalledFsDir, p.DownloadCache, p.RuntimeCache} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	return nil
}

// Arch is the canonical architecture token used inside the distro manifest
// ("aarch64", "armhf", "amd64"). Mirrors what the bash version's
// `dpkg --print-architecture` mapping produced so existing manifests work
// unchanged.
type Arch string

const (
	ArchAArch64 Arch = "aarch64"
	ArchArmhf   Arch = "armhf"
	ArchAmd64   Arch = "amd64"
)

// DetectArch translates runtime.GOARCH into the manifest token.
// Returns the empty string for unsupported architectures so callers can
// surface a friendly error rather than die deep in a lookup.
func DetectArch() Arch {
	switch runtime.GOARCH {
	case "arm64":
		return ArchAArch64
	case "arm":
		return ArchArmhf
	case "amd64":
		return ArchAmd64
	}
	return ""
}

func envOr(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}
