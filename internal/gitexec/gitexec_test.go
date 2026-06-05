package gitexec

import (
	"errors"
	"testing"
)

func TestIsTransientFetchError(t *testing.T) {
	// Each case documents the git stderr pattern it covers.
	transient := []struct {
		name string
		msg  string
	}{
		{"curl 18 transfer closed", "git fetch origin main: exit status 128 (stderr: error: RPC failed; curl 18 transfer closed with outstanding read data remaining)"},
		{"early eof lowercase", "git fetch origin main: exit status 128 (stderr: fatal: early EOF)"},
		{"early eof uppercase in wrapped", "git fetch origin dev: exit status 128 (stderr: error: 5000 bytes of body are still expected\nfetch-pack: unexpected disconnect while reading sideband packet\nfatal: early EOF)"},
		{"sideband disconnect", "git fetch origin main: exit status 128 (stderr: fetch-pack: unexpected disconnect while reading sideband packet)"},
		{"invalid index-pack output", "git fetch origin main: exit status 128 (stderr: fatal: fetch-pack: invalid index-pack output)"},
	}
	for _, tc := range transient {
		t.Run(tc.name, func(t *testing.T) {
			if !isTransientFetchError(errors.New(tc.msg)) {
				t.Errorf("expected transient=true for: %s", tc.msg)
			}
		})
	}

	permanent := []struct {
		name string
		msg  string
	}{
		{"repo not found", "git fetch origin main: exit status 128 (stderr: ERROR: Repository not found)"},
		{"http 401 auth", "git fetch origin main: exit status 128 (stderr: error: RPC failed; HTTP 401 Unauthorized)"},
		{"http 403 forbidden", "git fetch origin main: exit status 128 (stderr: error: RPC failed; HTTP 403 Forbidden)"},
		{"ref not found", "git fetch origin master: exit status 128 (stderr: fatal: couldn't find remote ref master)"},
		{"does not exist", "git fetch origin main: exit status 128 (stderr: fatal: remote error: repository 'x' does not exist)"},
		{"context deadline", "context deadline exceeded"},
		{"context cancelled", "context canceled"},
		{"nil error", ""},
	}
	for _, tc := range permanent {
		t.Run(tc.name, func(t *testing.T) {
			var err error
			if tc.msg != "" {
				err = errors.New(tc.msg)
			}
			if isTransientFetchError(err) {
				t.Errorf("expected transient=false for: %s", tc.msg)
			}
		})
	}
}
