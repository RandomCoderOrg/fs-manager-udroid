// Package manifest loads, parses, and queries the distro-data.json catalogue
// that drives installs. The bash version stores arch-specific URLs and
// checksums as top-level keys ("aarch64url", "aarch64sha", ...) inside each
// variant; we keep that wire format verbatim so existing caches and the
// upstream remote stay compatible.
//
// Note: the upstream manifest spells "variants" as "varients". We preserve
// that spelling rather than fix it — users' cached JSON would otherwise stop
// resolving.
package manifest

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/termux"
)

// Manifest is the parsed in-memory view of distro-data.json. It keeps the
// raw decoded tree because variant entries hold dynamic arch-keyed fields
// that don't map cleanly onto a static Go struct.
type Manifest struct {
	Suites []string                        `json:"suites"`
	raw    map[string]json.RawMessage
}

// Load parses distro-data.json from disk.
func Load(path string) (*Manifest, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read manifest: %w", err)
	}
	return Parse(b)
}

// Parse decodes manifest bytes.
func Parse(b []byte) (*Manifest, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(b, &raw); err != nil {
		return nil, fmt.Errorf("decode manifest: %w", err)
	}
	var head struct {
		Suites []string `json:"suites"`
	}
	if err := json.Unmarshal(b, &head); err != nil {
		return nil, fmt.Errorf("decode suites: %w", err)
	}
	return &Manifest{Suites: head.Suites, raw: raw}, nil
}

// Suite describes the inner shape of one suite ({"varients": [...], <variant>: {...}}).
type Suite struct {
	Variants []string                        `json:"varients"`
	raw      map[string]json.RawMessage
}

// Suite returns the suite section by name.
func (m *Manifest) Suite(name string) (*Suite, error) {
	r, ok := m.raw[name]
	if !ok {
		return nil, fmt.Errorf("suite %q not found", name)
	}
	var inner map[string]json.RawMessage
	if err := json.Unmarshal(r, &inner); err != nil {
		return nil, fmt.Errorf("decode suite %q: %w", name, err)
	}
	var head struct {
		Variants []string `json:"varients"`
	}
	if err := json.Unmarshal(r, &head); err != nil {
		return nil, fmt.Errorf("decode suite %q variants: %w", name, err)
	}
	return &Suite{Variants: head.Variants, raw: inner}, nil
}

// Variant is the resolved entry for a specific suite:variant pair on a
// specific architecture. SHASum may be empty when the upstream omits it.
type Variant struct {
	Suite        string
	Variant      string
	Name         string `json:"Name"`
	FriendlyName string `json:"FirendlyName"` // typo preserved from upstream
	URL          string
	SHASum       string
	SupportedArchs []string `json:"arch"`
}

// Variant resolves suite:variant on the given arch.
func (m *Manifest) Variant(suite, variant string, arch termux.Arch) (*Variant, error) {
	s, err := m.Suite(suite)
	if err != nil {
		return nil, err
	}
	r, ok := s.raw[variant]
	if !ok {
		return nil, fmt.Errorf("variant %q not found in suite %q", variant, suite)
	}
	// Decode static fields, then pull arch-keyed url/sha by string lookup.
	var v Variant
	if err := json.Unmarshal(r, &v); err != nil {
		return nil, fmt.Errorf("decode variant %q: %w", variant, err)
	}
	v.Suite = suite
	v.Variant = variant

	var dyn map[string]any
	if err := json.Unmarshal(r, &dyn); err != nil {
		return nil, fmt.Errorf("decode variant %q dyn: %w", variant, err)
	}
	if url, _ := dyn[string(arch)+"url"].(string); url != "" {
		v.URL = url
	}
	if sum, _ := dyn[string(arch)+"sha"].(string); sum != "" {
		v.SHASum = sum
	}
	return &v, nil
}

// HasSuite returns true when the suite is listed.
func (m *Manifest) HasSuite(name string) bool {
	for _, s := range m.Suites {
		if s == name {
			return true
		}
	}
	return false
}
