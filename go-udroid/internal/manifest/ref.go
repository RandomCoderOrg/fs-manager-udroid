package manifest

import (
	"fmt"
	"strings"
)

// Ref is a parsed "suite:variant" reference. Either side may be empty when
// the user typed a partial reference like "jammy" or ":xfce4" — callers can
// then prompt the user to fill in the missing half.
type Ref struct {
	Suite   string
	Variant string
}

// ParseRef accepts "suite:variant", "suite", or ":variant". An empty string
// returns an empty Ref without error so callers can decide whether that
// is a fatal condition.
func ParseRef(s string) (Ref, error) {
	if s == "" {
		return Ref{}, nil
	}
	parts := strings.SplitN(s, ":", 2)
	r := Ref{Suite: parts[0]}
	if len(parts) == 2 {
		r.Variant = parts[1]
	}
	if r.Suite != "" && r.Variant != "" && r.Suite == r.Variant {
		return r, fmt.Errorf("suite and variant cannot be identical (%q)", s)
	}
	return r, nil
}

// String renders the canonical "suite:variant" form.
func (r Ref) String() string {
	return r.Suite + ":" + r.Variant
}

// Complete returns true when both halves are set.
func (r Ref) Complete() bool { return r.Suite != "" && r.Variant != "" }
