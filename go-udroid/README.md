# go-udroid

A Go port of [fs-manager-udroid](../README.md) — a proot wrapper that installs
Linux rootfs tarballs as containers on Termux/Android.

The core packages (`internal/proot`, `internal/manifest`, `internal/rootfs`)
are independent of the CLI so a Bubble Tea TUI can reuse them later without
changes.

## Build

Quickest path on Termux: run the install script. It checks for `go`,
`proot`, and `tar`, offers to install whichever are missing, builds a
static binary, and drops it as `udroid-go` so the bash `udroid` can stay
in place.

```bash
cd go-udroid
./install.sh                       # interactive; installs to $PREFIX/bin/udroid-go
./install.sh -y                    # non-interactive
./install.sh --no-install          # build-only, leaves ./udroid-go in cwd
./install.sh --prefix=/opt/udroid  # install elsewhere
./install.sh --bin-name=udroid     # override the binary name
./install.sh --skip-deps           # caller already has deps on PATH
```

Manual build, if you'd rather not run a script:

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

The CLI surface covers everything the bash version offered plus a small set
of docker-shaped verbs (`pull`, `exec`, `images`, `inspect`, `info`,
`search`, `rmi`) for users coming from that ecosystem. Run `udroid help` for
the full list.

### Browse

```bash
udroid list                                 # installed + available
udroid list --size                          # include on-disk size
udroid list --installed                     # only installed
udroid images                               # alias for `list`
udroid search jammy                         # substring match on suite/variant/friendly name
udroid info                                 # paths, manifest URL, install/cache totals
udroid info --json                          # same data, machine-readable
udroid inspect ubuntu-jammy                 # JSON: size, mtime, applied fixes, manifest match
```

### Install / cache lifecycle

```bash
udroid pull jammy:raw                       # download tarball into cache, no install
udroid install jammy:raw                    # download + extract + apply fixes
udroid install --file ./my.tar.xz --name x  # install a local tarball as "custom-x"
udroid remove jammy:raw                     # uninstall
udroid reset  jammy:raw                     # remove + reinstall
udroid rmi jammy:raw                        # drop a single cached tarball
udroid cache update                         # refresh distro manifest
udroid cache clear                          # drop all cached tarballs
```

### Run

```bash
udroid login jammy:raw                      # interactive shell
udroid login --profile dev jammy:raw        # use a saved login profile
udroid login jammy:raw -- echo hello        # one-shot command via `--`
udroid login --custom my-rootfs             # log into a custom install
udroid login --dry-run jammy:raw            # print proot argv and exit

udroid exec ubuntu-jammy ls -la /tmp        # one-shot, no `--` needed
udroid exec -u alice ubuntu-jammy env       # run as a specific user
```

**`exec` flag handling:** flags for udroid (e.g. `-u`) must come **before**
the rootfs name. Everything after the name — including dash-prefixed tokens
like `-la` or `--foo` — is forwarded verbatim to the inner command. Matches
`docker exec` behaviour.

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

**Full profile schema.** Every key below is optional. Boolean fields are
pointers internally so omitting them means "inherit"; setting them to
`true` or `false` is what flips the toggle. Strings/lists fall back to the
zero value when absent.

| Field            | Type           | Effect when set |
|------------------|----------------|-----------------|
| `user`           | string         | login user inside the rootfs (default `root`) |
| `binds`          | list of string | extra `--bind` entries; each is `src` or `src:dst` |
| `command`        | list of string | run this once instead of an interactive shell |
| `run_script`     | string         | host-side script copied into rootfs and exec'd |
| `isolated`       | bool           | skip termux/storage/host-cwd mounts |
| `link2symlink`   | bool           | proot `--link2symlink` (default `true`) |
| `sysvipc`        | bool           | proot `--sysvipc` (default `true`) |
| `kill_on_exit`   | bool           | proot `--kill-on-exit` (default `true`) |
| `fake_root_id`   | bool           | proot `--root-id` (default `true`) |
| `cap_last_cap_fix` | bool         | bind-mask `/proc/sys/kernel/cap_last_cap` (default `true`) |
| `shared_tmp`     | bool           | bind termux `$PREFIX/tmp` to `/tmp` (default `true`) |
| `fix_low_ports`  | bool           | proot `-p`, allow ports < 1024 |
| `ashmem_memfd`   | bool           | proot `--ashmem-memfd` (experimental) |
| `pulse_server`   | bool           | start host pulseaudio with TCP loopback (default `true`) |

The same schema applies to the top-level `defaults:` block — it is just a
profile that always runs.

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
