package proot

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

// Binary is the name (or absolute path) of the proot executable. Override
// this at startup if proot is staged somewhere unusual.
var Binary = "proot"

// Login executes proot with the args derived from o, wiring stdin/stdout
// directly to the calling process so the user's terminal works correctly.
// On unix-like systems this performs an exec(2) replacement so proot
// becomes the foreground process — the Go binary never returns.
func Login(o Options) error {
	if err := o.Validate(); err != nil {
		return err
	}
	if o.RunScript != "" {
		if err := stageRunScript(o.RootFS, o.RunScript); err != nil {
			return err
		}
	}
	if o.PulseServer {
		startPulseAudio()
	}
	args := append([]string{Binary}, BuildArgs(o)...)
	bin, err := exec.LookPath(Binary)
	if err != nil {
		return fmt.Errorf("proot not found in PATH: %w", err)
	}
	slog.Info("proot login exec",
		slog.String("rootfs", o.RootFS),
		slog.String("user", o.LoginUser),
		slog.Int("argc", len(args)),
	)
	slog.Debug("proot argv", slog.Any("args", args))
	// Use exec(2) replacement to drop the Go process — proot becomes pid.
	return syscall.Exec(bin, args, os.Environ())
}

// startPulseAudio kicks off the host's pulseaudio daemon with TCP loopback
// enabled so audio inside the container reaches Android's mixer. Best
// effort — failures (missing binary, already running, etc.) are logged at
// debug level so non-audio installs aren't bothered.
func startPulseAudio() {
	bin, err := exec.LookPath("pulseaudio")
	if err != nil {
		slog.Debug("pulseaudio not found; skipping", slog.Any("err", err))
		return
	}
	if err := exec.Command(bin,
		"--start",
		`--load=module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1`,
		"--exit-idle-time=-1",
	).Run(); err != nil {
		slog.Debug("pulseaudio start failed", slog.Any("err", err))
		return
	}
	slog.Debug("pulseaudio started")
}

// stageRunScript copies a host script into the rootfs root so the inner
// `su -c /<script>` invocation can find it.
func stageRunScript(rootFS, hostPath string) error {
	src, err := os.Open(hostPath)
	if err != nil {
		return fmt.Errorf("run-script %q: %w", hostPath, err)
	}
	defer src.Close()
	dest := filepath.Join(rootFS, filepath.Base(hostPath))
	out, err := os.OpenFile(dest, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o755)
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, src)
	return err
}

// ExtractTarball drives `proot --link2symlink tar` to unpack a tarball into
// dest. proot is required (rather than native archive/tar) because Linux
// rootfs tarballs contain hard links that don't survive Android's
// filesystem without proot's --link2symlink translation.
//
// Compression is autodetected by tar — gz/xz/bz2 all work.
func ExtractTarball(ctx context.Context, tarball, dest string) error {
	if _, err := os.Stat(tarball); err != nil {
		return fmt.Errorf("tarball %q: %w", tarball, err)
	}
	if err := os.MkdirAll(dest, 0o755); err != nil {
		return err
	}
	bin, err := exec.LookPath(Binary)
	if err != nil {
		return fmt.Errorf("proot not found in PATH: %w", err)
	}
	slog.Info("extracting tarball",
		slog.String("src", tarball),
		slog.String("dest", dest),
	)
	cmd := exec.CommandContext(ctx, bin,
		"--link2symlink",
		"tar", "--no-same-owner", "-xpf", tarball, "-C", dest,
	)
	cmd.Env = filterEnv(os.Environ(), "LD_PRELOAD")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		slog.Error("extraction failed", slog.Any("err", err))
		return err
	}
	return nil
}

func filterEnv(env []string, drop ...string) []string {
	out := make([]string, 0, len(env))
	for _, e := range env {
		hide := false
		for _, k := range drop {
			if strings.HasPrefix(e, k+"=") {
				hide = true
				break
			}
		}
		if !hide {
			out = append(out, e)
		}
	}
	return out
}
