// Package config loads runtime configuration for udroid.
//
// Resolution order (highest priority first):
//  1. CLI flags (the caller binds them to viper)
//  2. UDROID_* env vars
//  3. $UDROID_CONFIG file, then $XDG_CONFIG_HOME/udroid/config.yaml,
//     then $HOME/.config/udroid/config.yaml
//  4. Built-in defaults
//
// LoginProfile lets users save a named bundle of proot toggles and binds
// and recall it via `udroid login --profile <name> <suite>:<variant>`.
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/viper"
)

// Config is the in-memory shape of config.yaml.
type Config struct {
	ManifestURL string                  `mapstructure:"manifest_url"`
	Paths       PathsOverride           `mapstructure:"paths"`
	Profiles    map[string]LoginProfile `mapstructure:"profiles"`
	Defaults    LoginProfile            `mapstructure:"defaults"`
	Log         LogConfig               `mapstructure:"log"`
}

// LogConfig configures the slog-backed logger. All fields are optional;
// CLI flags override anything set here.
type LogConfig struct {
	Level  string `mapstructure:"level"`  // debug|info|warn|error
	File   string `mapstructure:"file"`   // path; empty = $TMPDIR/udroid.log
	Format string `mapstructure:"format"` // text|json
}

// PathsOverride lets users redirect any of the canonical directories.
// Empty values fall back to termux.DefaultPaths().
type PathsOverride struct {
	Prefix          string `mapstructure:"prefix"`
	Home            string `mapstructure:"home"`
	Root            string `mapstructure:"root"`
	InstalledFsDir  string `mapstructure:"installed_fs_dir"`
	DownloadCache   string `mapstructure:"download_cache"`
	RuntimeCache    string `mapstructure:"runtime_cache"`
}

// LoginProfile is a re-usable bundle of proot login options. Boolean
// fields are pointers so we can distinguish "user said false" from "user
// didn't say anything"; nil means inherit from Defaults / Options default.
type LoginProfile struct {
	User           string   `mapstructure:"user"`
	Binds          []string `mapstructure:"binds"`
	Command        []string `mapstructure:"command"`
	RunScript      string   `mapstructure:"run_script"`
	Isolated       *bool    `mapstructure:"isolated"`
	Link2Symlink   *bool    `mapstructure:"link2symlink"`
	SysVIPC        *bool    `mapstructure:"sysvipc"`
	KillOnExit     *bool    `mapstructure:"kill_on_exit"`
	FakeRootID     *bool    `mapstructure:"fake_root_id"`
	CapLastCapFix  *bool    `mapstructure:"cap_last_cap_fix"`
	SharedTmp      *bool    `mapstructure:"shared_tmp"`
	FixLowPorts    *bool    `mapstructure:"fix_low_ports"`
	AshmemMemfd    *bool    `mapstructure:"ashmem_memfd"`
	PulseServer    *bool    `mapstructure:"pulse_server"`
}

// Load reads config from the canonical locations and returns a populated
// Config. Missing config files are not an error — the defaults kick in.
func Load(explicitPath string) (*Config, error) {
	v := viper.New()
	v.SetConfigType("yaml")
	v.SetEnvPrefix("UDROID")
	v.AutomaticEnv()
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// defaults
	v.SetDefault("manifest_url", "https://raw.githubusercontent.com/RandomCoderOrg/udroid-download/main/distro-data.json")

	switch {
	case explicitPath != "":
		v.SetConfigFile(explicitPath)
	default:
		if p := os.Getenv("UDROID_CONFIG"); p != "" {
			v.SetConfigFile(p)
		} else {
			v.SetConfigName("config")
			for _, dir := range configDirs() {
				v.AddConfigPath(dir)
			}
		}
	}

	if err := v.ReadInConfig(); err != nil {
		// Missing file is fine — only fail on parse errors.
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			if !os.IsNotExist(err) {
				return nil, fmt.Errorf("read config: %w", err)
			}
		}
	}

	var c Config
	if err := v.Unmarshal(&c); err != nil {
		return nil, fmt.Errorf("decode config: %w", err)
	}
	return &c, nil
}

// configDirs returns the search path in priority order.
func configDirs() []string {
	var dirs []string
	if x := os.Getenv("XDG_CONFIG_HOME"); x != "" {
		dirs = append(dirs, filepath.Join(x, "udroid"))
	}
	if h, err := os.UserHomeDir(); err == nil {
		dirs = append(dirs, filepath.Join(h, ".config", "udroid"))
	}
	dirs = append(dirs, "/etc/udroid")
	return dirs
}

// Profile returns the named profile or false if it doesn't exist.
func (c *Config) Profile(name string) (LoginProfile, bool) {
	if c.Profiles == nil {
		return LoginProfile{}, false
	}
	p, ok := c.Profiles[name]
	return p, ok
}

// BoolDeref returns *p when non-nil and fallback otherwise — used when
// merging profile bools into Options.
func BoolDeref(p *bool, fallback bool) bool {
	if p == nil {
		return fallback
	}
	return *p
}
