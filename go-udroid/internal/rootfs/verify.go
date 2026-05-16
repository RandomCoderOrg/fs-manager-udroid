package rootfs

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
)

// VerifySHA256 returns nil when path's sha256 matches expected.
// An empty expected sum is treated as "no check requested" and returns nil.
func VerifySHA256(path, expected string) error {
	if expected == "" {
		return nil
	}
	got, err := SHA256(path)
	if err != nil {
		return err
	}
	if got != expected {
		return fmt.Errorf("sha256 mismatch: got %s, want %s", got, expected)
	}
	return nil
}

// SHA256 returns the hex-encoded sha256 digest of the file at path.
func SHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
