package util

import (
	"syscall"
)

// GetFreeSpace returns the number of free bytes for the given path
func GetFreeSpace(path string) (uint64, error) {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(path, &stat); err != nil {
		return 0, err
	}

	// Available blocks * size per block = available bytes
	return stat.Bavail * uint64(stat.Bsize), nil
}
