package rootfs

import (
	"fmt"
	"io/fs"
	"log/slog"
	"os"
	"path/filepath"
)

// Remove deletes a rootfs at path. Replaces proot-uninstall-suite.sh —
// first chmods every entry to ensure we have write+execute, then removes
// the tree. Returns an error rather than the bash version's silent exit.
func Remove(path string) error {
	if _, err := os.Stat(path); err != nil {
		return fmt.Errorf("rootfs %q: %w", path, err)
	}
	slog.Info("removing rootfs", slog.String("path", path))
	_ = filepath.WalkDir(path, func(p string, _ fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		_ = os.Chmod(p, 0o700)
		return nil
	})
	if err := os.RemoveAll(path); err != nil {
		slog.Error("rootfs remove failed", slog.String("path", path), slog.Any("err", err))
		return err
	}
	return nil
}

// Size returns the recursive on-disk size in bytes.
func Size(path string) (int64, error) {
	var total int64
	err := filepath.WalkDir(path, func(_ string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		total += info.Size()
		return nil
	})
	return total, err
}
