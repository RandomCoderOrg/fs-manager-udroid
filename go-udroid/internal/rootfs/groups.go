package rootfs

import (
	"os/exec"
	"strconv"
	"strings"
)

// HostAndroidGroups returns the host's supplementary GIDs paired with their
// names, mirroring `paste <(id -Gn) <(id -G)`. Used to teach a fresh rootfs
// about Android's aid_* groups so apps that probe membership work.
//
// On non-Android hosts (e.g. dev laptops) this returns whatever
// supplementary groups exist; callers can drop the result if they don't
// want host groups bleeding into the container.
func HostAndroidGroups() ([]AndroidGroup, error) {
	names, err := runID("-Gn")
	if err != nil {
		return nil, err
	}
	gids, err := runID("-G")
	if err != nil {
		return nil, err
	}
	nameFields := strings.Fields(names)
	gidFields := strings.Fields(gids)
	n := len(nameFields)
	if len(gidFields) < n {
		n = len(gidFields)
	}
	out := make([]AndroidGroup, 0, n)
	for i := 0; i < n; i++ {
		gid, err := strconv.Atoi(gidFields[i])
		if err != nil {
			continue
		}
		out = append(out, AndroidGroup{Name: nameFields[i], GID: gid})
	}
	return out, nil
}

func runID(arg string) (string, error) {
	out, err := exec.Command("id", arg).Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(out)), nil
}
