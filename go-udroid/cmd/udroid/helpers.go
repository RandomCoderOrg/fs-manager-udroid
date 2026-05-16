package main

import (
	"context"
	"fmt"

	"github.com/RandomCoderOrg/fs-manager-udroid/go-udroid/internal/manifest"
)

// loadManifest builds a fetcher honouring the user's manifest_url override.
func loadManifest(ctx context.Context, a *app, mode manifest.Mode, strict bool) (*manifest.Manifest, error) {
	f := manifest.NewFetcher(a.paths.RuntimeCache)
	if a.cfg != nil && a.cfg.ManifestURL != "" {
		f.URL = a.cfg.ManifestURL
	}
	return f.Load(ctx, mode, strict)
}

// resolveRef fills in missing suite or variant via interactive prompts,
// returning an error if the user supplied a value that isn't in the manifest.
func resolveRef(a *app, mf *manifest.Manifest, ref manifest.Ref) (manifest.Ref, error) {
	if ref.Suite == "" {
		s, err := a.ui.Choose("select suite", mf.Suites)
		if err != nil {
			return ref, err
		}
		ref.Suite = s
	}
	if !mf.HasSuite(ref.Suite) {
		return ref, fmt.Errorf("suite %q not in manifest", ref.Suite)
	}
	suite, err := mf.Suite(ref.Suite)
	if err != nil {
		return ref, err
	}
	if ref.Variant == "" {
		v, err := a.ui.Choose("select variant", suite.Variants)
		if err != nil {
			return ref, err
		}
		ref.Variant = v
	}
	found := false
	for _, v := range suite.Variants {
		if v == ref.Variant {
			found = true
			break
		}
	}
	if !found {
		return ref, fmt.Errorf("variant %q not in suite %q", ref.Variant, ref.Suite)
	}
	return ref, nil
}
