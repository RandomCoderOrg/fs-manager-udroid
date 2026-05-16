# go-udroid

A Go port of [fs-manager-udroid](../README.md) — a proot wrapper that installs
Linux rootfs tarballs as containers on Termux/Android.

This port is designed so the same core (`internal/proot`, `internal/manifest`,
`internal/rootfs`) can later back a Bubble Tea TUI without touching the
business logic.

## Build

```bash
cd go-udroid
go build -o udroid ./cmd/udroid
```

Static cross-compile for Termux (no CGO):

```bash
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
  go build -ldflags='-s -w' -o udroid-linux-arm64 ./cmd/udroid
```

## Usage

The CLI surface mirrors the bash version. Run `udroid help` for the full list.

```bash
udroid install jammy:raw                    # download + extract + apply fixes
udroid login jammy:raw                      # interactive shell
udroid login --profile dev jammy:raw        # use a saved login profile
udroid login jammy:raw -- echo hello        # one-shot command
udroid login --custom my-rootfs             # log into a custom install
udroid list --size                          # tabulate installed/available
udroid remove jammy:raw                     # uninstall
udroid reset  jammy:raw                     # remove + reinstall
udroid cache update                         # refresh distro manifest
udroid cache clear                          # drop downloaded tarballs
```

## Configuration

Drop a YAML file at `~/.config/udroid/config.yaml` (or point `UDROID_CONFIG`
at any path). See [`config.example.yaml`](./config.example.yaml).

Resolution order (highest priority first):

1. CLI flags
2. `UDROID_*` env vars
3. `--config <path>` / `$UDROID_CONFIG`
4. `$XDG_CONFIG_HOME/udroid/config.yaml` then `~/.config/udroid/config.yaml`
5. Built-in defaults

### Logging

Diagnostic events are written to `$TMPDIR/udroid.log` (configurable). The
log is structured via `log/slog`; pick `text` or `json` formatting.

| flag | config key | default |
|---|---|---|
| `--log-level` | `log.level`  | `info` |
| `--log-file`  | `log.file`   | `$TMPDIR/udroid.log` |
| `--log-format`| `log.format` | `text` |
| `--verbose`/`-v` | — | mirror log output to stderr |

Set `--log-level=debug --verbose` while diagnosing an issue to see every
event on stderr in real time.

### Profiles

Save a named bundle of login flags and recall them by name:

```yaml
profiles:
  dev:
    user: dev
    binds: [/sdcard/projects:/workspace]
    isolated: false
```

```bash
udroid login --profile dev jammy:raw
```

CLI flags always win over profile values, profile values win over `defaults`.

## Layout

```
cmd/udroid/             # cobra entrypoints — thin glue
internal/
  manifest/             # distro-data.json fetch + parse + ref parsing
  proot/                # typed Options, BuildArgs (pure), exec wrappers
  rootfs/               # download / verify / extract / fixes / remove
  config/               # viper-loaded yaml + profile merging
  ui/                   # UI interface + plain implementation
  termux/               # path constants + arch detection
```

### The proot argv builder

`internal/proot/args.go::BuildArgs(Options) []string` is a pure function.
It turns a typed `Options` struct into the argv that's handed to
`exec.Command("proot", ...)`. No I/O, no globals, fully deterministic, so
the CLI and a future TUI can share the same call.

## Shelled-out commands

The Go port keeps a strict static binary. The only external program it
invokes is `proot` itself, for:

- **Extraction** — needs `proot --link2symlink tar` because Linux rootfs
  tarballs contain hard links that don't survive on Android's filesystem
  without proot's link2symlink translation.
- **Login** — replaces the Go process via `syscall.Exec` so proot becomes
  the foreground process the user interacts with.

Everything else (HTTP, sha256, JSON, arch detection, /proc fake files,
group entries) is native Go.

## Testing

```bash
go test ./...
```

There's coverage on the args builder (the riskiest piece) and on the
manifest parser against the existing `udroid/src/test.json` fixture so
changes can't silently break the on-disk format.

## Status

This is an early port. It exercises the same code paths as the bash
version but hasn't yet been exercised on real Termux installs across the
same matrix of distros and Android versions. Treat as alpha until it
ships its first release.

### Known regressions vs. the bash version

- **No partial-download resume.** Bash uses `wget -c`; this port restarts
  from byte 0 on retry. Acceptable on stable links, noticeable on flaky
  mobile data.
- **`list --size` is slower.** Bash shelled out to `du -sh`; the Go
  version walks the tree natively. Multi-GB installs may take a few
  seconds to size up.
