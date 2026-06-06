package gitexec

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"
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
	}
	for _, tc := range permanent {
		t.Run(tc.name, func(t *testing.T) {
			if isTransientFetchError(errors.New(tc.msg)) {
				t.Errorf("expected transient=false for: %s", tc.msg)
			}
		})
	}

	// Test the nil guard directly — the table loop would pass errors.New("") which
	// is a non-nil error with an empty message, not a true nil.
	t.Run("nil error returns false", func(t *testing.T) {
		if isTransientFetchError(nil) {
			t.Error("isTransientFetchError(nil) must return false")
		}
	})

	// Verify that strings.ToLower is applied — matching must be case-insensitive.
	t.Run("case insensitive CURL 18", func(t *testing.T) {
		if !isTransientFetchError(errors.New("CURL 18 TRANSFER CLOSED")) {
			t.Error("expected transient=true for upper-case CURL 18")
		}
	})
	t.Run("case insensitive EARLY EOF", func(t *testing.T) {
		if !isTransientFetchError(errors.New("fatal: EARLY EOF")) {
			t.Error("expected transient=true for upper-case EARLY EOF")
		}
	})

	// Guard against substring over-matching: "curl 186" must NOT match "curl 18 ".
	t.Run("curl 186 does not false-positive as curl 18", func(t *testing.T) {
		if isTransientFetchError(errors.New("hook: curl 186 bytes processed")) {
			t.Error("curl 186 should not match the curl 18 transient pattern")
		}
	})
}

// TestFetchRetryDelaysInvariant verifies that fetchRetryDelays has exactly
// FetchMaxAttempts-1 positive-duration entries. This is the runtime guard for
// the coupling between the constant and the slice: if FetchMaxAttempts is bumped
// without a corresponding delay, this test fails at CI time. The positivity check
// ensures a negative/zero entry cannot silently make retries instantaneous.
func TestFetchRetryDelaysInvariant(t *testing.T) {
	want := FetchMaxAttempts - 1
	if len(fetchRetryDelays) != want {
		t.Fatalf("fetchRetryDelays has %d entries, want %d (= FetchMaxAttempts-1 = %d-1)",
			len(fetchRetryDelays), want, FetchMaxAttempts)
	}
	for i, d := range fetchRetryDelays {
		if d <= 0 {
			t.Errorf("fetchRetryDelays[%d] = %v; must be > 0 to avoid instantaneous retries", i, d)
		}
	}
}

// TestFetchMultiRef covers FetchMultiRef boundary conditions that do not require
// a real git remote (context cancellation before any ref is attempted, empty
// refs slice). Scenarios that do reach the network belong in integration tests.
func TestFetchMultiRef(t *testing.T) {
	t.Run("empty refs returns no-refs error", func(t *testing.T) {
		err := FetchMultiRef(context.Background(), 100*time.Millisecond, t.TempDir(), nil)
		if err == nil {
			t.Fatal("want error for empty refs, got nil")
		}
		if !strings.Contains(err.Error(), "no parent candidate refs available") {
			t.Errorf("unexpected error: %v", err)
		}
	})

	t.Run("pre-cancelled context returns ctx.Err before any network call", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel()

		// The loop guard fires on the first iteration; no git subprocess is launched.
		err := FetchMultiRef(ctx, 100*time.Millisecond, t.TempDir(), []string{"refs/heads/main"})
		if !errors.Is(err, context.Canceled) {
			t.Errorf("want context.Canceled, got %v", err)
		}
	})

	t.Run("context deadline expired returns DeadlineExceeded before any network call", func(t *testing.T) {
		ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Second))
		defer cancel()

		err := FetchMultiRef(ctx, 100*time.Millisecond, t.TempDir(), []string{"refs/heads/main"})
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Errorf("want context.DeadlineExceeded, got %v", err)
		}
	})
}

// TestFetchWithRetry covers the retry-loop behavior using a controllable fetch
// stub. Because fetchWithRetry accepts a func(context.Context) error, no real
// git subprocess is required.
func TestFetchWithRetry(t *testing.T) {
	transientErr := errors.New("fatal: early eof") // matches isTransientFetchError

	t.Run("succeeds on first attempt", func(t *testing.T) {
		calls := 0
		err := fetchWithRetry(context.Background(), 100*time.Millisecond, func(_ context.Context) error {
			calls++
			return nil
		})
		if err != nil {
			t.Fatalf("want nil, got %v", err)
		}
		if calls != 1 {
			t.Fatalf("want 1 call, got %d", calls)
		}
	})

	t.Run("retries transient error and succeeds on second attempt", func(t *testing.T) {
		calls := 0
		err := fetchWithRetry(context.Background(), 100*time.Millisecond, func(_ context.Context) error {
			calls++
			if calls == 1 {
				return transientErr
			}
			return nil
		})
		if err != nil {
			t.Fatalf("want nil after retry, got %v", err)
		}
		if calls != 2 {
			t.Fatalf("want 2 calls, got %d", calls)
		}
	})

	t.Run("exhausts all attempts on transient error", func(t *testing.T) {
		calls := 0
		err := fetchWithRetry(context.Background(), 100*time.Millisecond, func(_ context.Context) error {
			calls++
			return transientErr
		})
		if err == nil {
			t.Fatal("want error after exhausting attempts, got nil")
		}
		if calls != FetchMaxAttempts {
			t.Fatalf("want %d attempts, got %d", FetchMaxAttempts, calls)
		}
		// Error must mention attempt count for operational context.
		// Check the full prefix so a rename of the message is caught explicitly.
		if !strings.HasPrefix(err.Error(), "fetch failed after") {
			t.Errorf("error should start with 'fetch failed after', got: %v", err)
		}
	})

	t.Run("does not retry permanent error", func(t *testing.T) {
		calls := 0
		err := fetchWithRetry(context.Background(), 100*time.Millisecond, func(_ context.Context) error {
			calls++
			return errors.New("ERROR: Repository not found")
		})
		if err == nil {
			t.Fatal("want error, got nil")
		}
		if calls != 1 {
			t.Fatalf("want exactly 1 attempt (no retry on permanent), got %d", calls)
		}
	})

	t.Run("respects already-cancelled context before first attempt", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel() // cancel before calling

		calls := 0
		err := fetchWithRetry(ctx, 100*time.Millisecond, func(_ context.Context) error {
			calls++
			return nil
		})
		if !errors.Is(err, context.Canceled) {
			t.Fatalf("want context.Canceled, got %v", err)
		}
		if calls != 0 {
			t.Fatalf("want 0 fetch calls on pre-cancelled ctx, got %d", calls)
		}
	})

	t.Run("respects context cancelled between attempts", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())

		calls := 0
		err := fetchWithRetry(ctx, 100*time.Millisecond, func(_ context.Context) error {
			calls++
			cancel() // cancel after first transient failure — fires during next backoff check
			return transientErr
		})
		if err == nil {
			t.Fatal("want error on cancelled ctx, got nil")
		}
		// Should have been cancelled before or during the backoff sleep after attempt 0.
		if calls > 1 {
			t.Fatalf("want at most 1 fetch call before ctx cancel propagates, got %d", calls)
		}
	})

	t.Run("jitter rand.Int63n branch exercises with non-zero base delay", func(t *testing.T) {
		// Override fetchRetryDelays to use a small non-zero value so that
		// int64(base)/2 > 0 and rand.Int63n is actually invoked (not guarded out).
		// This verifies that the jitter branch runs without panic under realistic delays.
		orig := fetchRetryDelays
		fetchRetryDelays = []time.Duration{10 * time.Millisecond}
		defer func() { fetchRetryDelays = orig }()

		calls := 0
		err := fetchWithRetry(context.Background(), 100*time.Millisecond, func(_ context.Context) error {
			calls++
			if calls == 1 {
				return transientErr // triggers backoff + jitter before attempt 2
			}
			return nil
		})
		if err != nil {
			t.Fatalf("want nil on second attempt, got %v", err)
		}
		if calls != 2 {
			t.Fatalf("want 2 calls (1 transient + 1 success), got %d", calls)
		}
		// If we reach here, rand.Int63n(5_000_000) ran without panic.
	})
}

// TestFetchWithRetry_PerAttemptTimeout exercises the per-attempt timeout
// derivation: with a generous parent budget, the loop should attempt up to
// FetchMaxAttempts times even when each attempt fails with a transient
// curl-18-class error within its per-attempt window.
func TestFetchWithRetry_PerAttemptTimeout(t *testing.T) {
	origDelays := fetchRetryDelays
	fetchRetryDelays = []time.Duration{1 * time.Millisecond, 1 * time.Millisecond}
	defer func() { fetchRetryDelays = origDelays }()

	parentCtx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()

	attempts := 0
	perAttempt := 50 * time.Millisecond
	err := fetchWithRetry(parentCtx, perAttempt, func(_ context.Context) error {
		attempts++
		time.Sleep(5 * time.Millisecond)
		return errors.New("error: RPC failed; curl 18 transfer closed")
	})
	if attempts != FetchMaxAttempts {
		t.Errorf("got %d attempts, want %d", attempts, FetchMaxAttempts)
	}
	if err == nil || !strings.Contains(err.Error(), "curl 18") {
		t.Errorf("err %v does not preserve last curl 18", err)
	}
}

// TestFetchWithRetry_ParentBudgetExhausted verifies that the loop exits
// early when parentCtx expires, NOT making the full FetchMaxAttempts.
func TestFetchWithRetry_ParentBudgetExhausted(t *testing.T) {
	origDelays := fetchRetryDelays
	fetchRetryDelays = []time.Duration{20 * time.Millisecond, 20 * time.Millisecond}
	defer func() { fetchRetryDelays = origDelays }()

	parentCtx, cancel := context.WithTimeout(context.Background(), 30*time.Millisecond)
	defer cancel()

	attempts := 0
	perAttempt := 200 * time.Millisecond
	err := fetchWithRetry(parentCtx, perAttempt, func(ctx context.Context) error {
		attempts++
		select {
		case <-time.After(25 * time.Millisecond):
			return errors.New("error: RPC failed; curl 18 transfer closed")
		case <-ctx.Done():
			return ctx.Err()
		}
	})
	if attempts >= FetchMaxAttempts {
		t.Errorf("expected early exit, got %d attempts", attempts)
	}
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("err %v is not DeadlineExceeded", err)
	}
}

// TestFetchWithRetry_PerAttemptCancelsLongAttempt verifies that per-attempt
// expiry is treated as transient and retried within the remaining parent
// budget. With strict per-attempt timeout and a long lambda, we expect
// exactly FetchMaxAttempts attempts and the "fetch failed after" wrapper.
func TestFetchWithRetry_PerAttemptCancelsLongAttempt(t *testing.T) {
	origDelays := fetchRetryDelays
	fetchRetryDelays = []time.Duration{1 * time.Millisecond, 1 * time.Millisecond}
	defer func() { fetchRetryDelays = origDelays }()

	parentCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	perAttempt := 20 * time.Millisecond
	attempts := 0
	err := fetchWithRetry(parentCtx, perAttempt, func(ctx context.Context) error {
		attempts++
		select {
		case <-time.After(100 * time.Millisecond):
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	})
	if attempts != FetchMaxAttempts {
		t.Errorf("attempts = %d, want %d (per-attempt expiry should retry)", attempts, FetchMaxAttempts)
	}
	if err == nil {
		t.Fatal("expected non-nil err after exhausting attempts")
	}
	if !strings.Contains(err.Error(), "fetch failed after") {
		t.Errorf("err = %v; expected 'fetch failed after' wrapper", err)
	}
}

// TestIsTransientFetchError_NewPatterns covers the additional patterns added
// alongside the http.version=HTTP/1.1 / lowSpeed mitigation work. curl 28
// fires on operation-timed-out / lowSpeed thresholds; gnutls_handshake and
// SSL_read cover TLS-layer flakes on macOS (gnutls) and Linux (openssl).
func TestIsTransientFetchError_NewPatterns(t *testing.T) {
	transient := []struct {
		name string
		msg  string
	}{
		{"curl 28 operation timeout", "git fetch: exit status 128 (stderr: fatal: unable to access 'https://example/': Operation timed out after 60000 ms; curl 28 Operation too slow)"},
		{"operation timed out lowercase", "fatal: unable to access 'https://x': operation timed out"},
		{"gnutls handshake", "fatal: unable to access 'https://x': gnutls_handshake() failed: An unexpected TLS packet was received"},
		{"openssl ssl_read", "fatal: unable to access 'https://x': OpenSSL SSL_read: Connection reset by peer, errno 54"},
	}
	for _, tc := range transient {
		t.Run(tc.name, func(t *testing.T) {
			if !isTransientFetchError(errors.New(tc.msg)) {
				t.Errorf("expected transient=true for: %s", tc.msg)
			}
		})
	}

	// Negative guards — patterns that look similar but must NOT match.
	permanent := []struct {
		name string
		msg  string
	}{
		{"curl 22 http 404", "fatal: unable to access 'https://x': The requested URL returned error: 404; curl 22 The requested URL returned error"},
		{"auth failed", "fatal: Authentication failed for 'https://x'"},
	}
	for _, tc := range permanent {
		t.Run(tc.name, func(t *testing.T) {
			if isTransientFetchError(errors.New(tc.msg)) {
				t.Errorf("expected transient=false for: %s", tc.msg)
			}
		})
	}
}
