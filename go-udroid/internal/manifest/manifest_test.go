package manifest

import (
	"os"
	"strings"
	"testing"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/termux"
)

func TestParseAgainstExistingFixture(t *testing.T) {
	// The bash codebase ships udroid/src/test.json — reuse it to confirm
	// schema compatibility (including the "varients" misspelling we
	// deliberately preserve).
	for _, candidate := range []string{
		"../../../udroid/src/test.json",
	} {
		b, err := os.ReadFile(candidate)
		if err != nil {
			continue
		}
		m, err := Parse(b)
		if err != nil {
			t.Fatalf("parse: %v", err)
		}
		if !m.HasSuite("jammy") {
			t.Fatalf("expected jammy suite in %v", m.Suites)
		}
		v, err := m.Variant("jammy", "raw", termux.ArchAArch64)
		if err != nil {
			t.Fatalf("variant lookup: %v", err)
		}
		if !strings.HasPrefix(v.URL, "https://") {
			t.Errorf("expected aarch64url, got %q", v.URL)
		}
		if v.SHASum == "" {
			t.Errorf("expected aarch64sha, got empty")
		}
		if v.Name != "udroid-jammy-raw" {
			t.Errorf("expected canonical Name, got %q", v.Name)
		}
		return
	}
	t.Skip("test.json fixture not found")
}

func TestParseRef(t *testing.T) {
	cases := []struct {
		in       string
		wantS    string
		wantV    string
		wantErr  bool
	}{
		{"jammy:raw", "jammy", "raw", false},
		{"jammy", "jammy", "", false},
		{":xfce4", "", "xfce4", false},
		{"", "", "", false},
		{"x:x", "x", "x", true},
	}
	for _, c := range cases {
		r, err := ParseRef(c.in)
		if (err != nil) != c.wantErr {
			t.Errorf("ParseRef(%q) err = %v, wantErr %v", c.in, err, c.wantErr)
		}
		if r.Suite != c.wantS || r.Variant != c.wantV {
			t.Errorf("ParseRef(%q) = {%q,%q}, want {%q,%q}", c.in, r.Suite, r.Variant, c.wantS, c.wantV)
		}
	}
}
