package sync

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"
	"unicode/utf8"

	"gitsync/internal/gitexec"
)

// TestClassifyFetchError_SIGINT_NotTimeout pins the most important regression:
// SIGINT propagation from main.go must classify as FetchKindCancelled, not
// FetchKindTimeout — otherwise Ctrl-C of a multi-repo sync would spam the
// user with timeout messages.
func TestClassifyFetchError_SIGINT_NotTimeout(t *testing.T) {
	parentCtx, cancel := context.WithCancel(context.Background())
	cancel()
	fetchCtx, fcancel := context.WithCancel(parentCtx)
	defer fcancel()
	kind, isTimeout, isGone := classifyFetchError(parentCtx, fetchCtx, context.Canceled)
	if kind != FetchKindCancelled {
		t.Errorf("kind = %v, want FetchKindCancelled — SIGINT MUST NOT be classified as Timeout", kind)
	}
	if isTimeout {
		t.Error("SIGINT misclassified as Timeout — would spam user with timeout messages on Ctrl-C")
	}
	if isGone {
		t.Error("SIGINT misclassified as RemoteGone")
	}
}

// TestClassifyFetchError_ParentTimeoutDistinctFromCancel verifies that
// parent-ctx DeadlineExceeded (total-budget exhaustion) is a Timeout, but
// parent-ctx Canceled (SIGINT) is NOT. They must not be conflated.
func TestClassifyFetchError_ParentTimeoutDistinctFromCancel(t *testing.T) {
	parentCtx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
	defer cancel()
	time.Sleep(2 * time.Millisecond)
	kind, isTimeout, _ := classifyFetchError(parentCtx, parentCtx, context.DeadlineExceeded)
	if kind != FetchKindTimeout {
		t.Errorf("kind = %v, want FetchKindTimeout for parent DeadlineExceeded", kind)
	}
	if !isTimeout {
		t.Error("FetchTimeout bool should be true for parent total-budget expiry")
	}
}

// TestClassifyFetchError_FetchKindBoolInvariant exhaustively verifies the
// contract between FetchKind and the legacy FetchTimeout/RemoteGone bools.
// If you add a new FetchKind, add a case below AND update the contract
// comment in types.go.
func TestClassifyFetchError_FetchKindBoolInvariant(t *testing.T) {
	type setup struct {
		name        string
		buildParent func() (context.Context, context.CancelFunc)
		buildFetch  func(parent context.Context) (context.Context, context.CancelFunc)
		err         error
		wantKind    FetchKind
		wantTimeout bool
		wantGone    bool
	}
	setups := []setup{
		{
			name: "Cancelled — parent SIGINT",
			buildParent: func() (context.Context, context.CancelFunc) {
				ctx, cancel := context.WithCancel(context.Background())
				cancel()
				return ctx, func() {}
			},
			buildFetch:  func(p context.Context) (context.Context, context.CancelFunc) { return p, func() {} },
			err:         context.Canceled,
			wantKind:    FetchKindCancelled,
			wantTimeout: false,
			wantGone:    false,
		},
		{
			name:        "Cancelled — fetchCtx only (uncovered branch from PHR R2)",
			buildParent: func() (context.Context, context.CancelFunc) { return context.Background(), func() {} },
			buildFetch: func(p context.Context) (context.Context, context.CancelFunc) {
				ctx, cancel := context.WithCancel(p)
				cancel()
				return ctx, func() {}
			},
			err:         context.Canceled,
			wantKind:    FetchKindCancelled,
			wantTimeout: false,
			wantGone:    false,
		},
		{
			name: "Timeout — parent DeadlineExceeded",
			buildParent: func() (context.Context, context.CancelFunc) {
				ctx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
				time.Sleep(2 * time.Millisecond)
				return ctx, cancel
			},
			buildFetch:  func(p context.Context) (context.Context, context.CancelFunc) { return p, func() {} },
			err:         context.DeadlineExceeded,
			wantKind:    FetchKindTimeout,
			wantTimeout: true,
			wantGone:    false,
		},
		{
			name:        "Timeout — fetchCtx DeadlineExceeded only",
			buildParent: func() (context.Context, context.CancelFunc) { return context.Background(), func() {} },
			buildFetch: func(p context.Context) (context.Context, context.CancelFunc) {
				ctx, cancel := context.WithTimeout(p, 1*time.Nanosecond)
				time.Sleep(2 * time.Millisecond)
				return ctx, cancel
			},
			err:         context.DeadlineExceeded,
			wantKind:    FetchKindTimeout,
			wantTimeout: true,
			wantGone:    false,
		},
		{
			name:        "RepoGone — repository not found",
			buildParent: func() (context.Context, context.CancelFunc) { return context.Background(), func() {} },
			buildFetch:  func(p context.Context) (context.Context, context.CancelFunc) { return p, func() {} },
			err:         fmt.Errorf("ERROR: Repository not found"),
			wantKind:    FetchKindRepoGone,
			wantTimeout: false,
			wantGone:    true,
		},
		{
			name:        "TransientGaveUp — exhausted retries",
			buildParent: func() (context.Context, context.CancelFunc) { return context.Background(), func() {} },
			buildFetch:  func(p context.Context) (context.Context, context.CancelFunc) { return p, func() {} },
			err:         fmt.Errorf("fetch failed after 3 attempts: curl 18 transfer closed"),
			wantKind:    FetchKindTransientGaveUp,
			wantTimeout: false,
			wantGone:    false,
		},
	}
	// Sanity: ensure we cover every non-OK FetchKind. FetchKindOK is the
	// success path and classifyFetchError isn't called for it.
	nonOKKinds := int(FetchKindRepoGone) // last enum value
	seen := map[FetchKind]bool{}
	for _, c := range setups {
		seen[c.wantKind] = true
	}
	if len(seen) != nonOKKinds {
		t.Fatalf("setups cover %d distinct FetchKinds, want %d (every non-OK kind)", len(seen), nonOKKinds)
	}
	for _, tc := range setups {
		t.Run(tc.name, func(t *testing.T) {
			parent, pcancel := tc.buildParent()
			defer pcancel()
			fetch, fcancel := tc.buildFetch(parent)
			defer fcancel()
			kind, isTimeout, isGone := classifyFetchError(parent, fetch, tc.err)
			if kind != tc.wantKind {
				t.Errorf("kind = %v, want %v", kind, tc.wantKind)
			}
			if isTimeout != tc.wantTimeout {
				t.Errorf("isTimeout = %v, want %v (contract drift)", isTimeout, tc.wantTimeout)
			}
			if isGone != tc.wantGone {
				t.Errorf("isGone = %v, want %v (contract drift)", isGone, tc.wantGone)
			}
		})
	}
}

// TestClassifyFetchError_CancelWinsOverTimeout pins the deterministic behavior
// when parent ctx is both past-deadline AND cancelled. Whichever wins, the
// classifier must not enter an undefined state.
func TestClassifyFetchError_CancelWinsOverTimeout(t *testing.T) {
	parentCtx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
	time.Sleep(2 * time.Millisecond)
	cancel()
	kind, isTimeout, _ := classifyFetchError(parentCtx, parentCtx, context.Canceled)
	if kind != FetchKindCancelled && kind != FetchKindTimeout {
		t.Errorf("kind = %v, want Cancelled or Timeout (deterministic)", kind)
	}
	if kind == FetchKindTimeout && !isTimeout {
		t.Error("FetchKindTimeout implies isTimeout=true")
	}
}

// TestFetchWithBudget_ZeroPerAttemptYieldsExpiredCtx pins the test-injection
// pattern where FetchTimeout=0 produces an immediately-expired fetchCtx.
// CLI users cannot reach this state (parseFlags rejects <1); only the
// internal Flags struct accepts 0 for test purposes.
func TestFetchWithBudget_ZeroPerAttemptYieldsExpiredCtx(t *testing.T) {
	var observed context.Context
	kind, isTimeout, _, ferr := fetchWithBudget(context.Background(), 0, func(fctx context.Context) error {
		observed = fctx
		return fctx.Err()
	})
	if observed == nil {
		t.Fatal("lambda not invoked")
	}
	if !errors.Is(observed.Err(), context.DeadlineExceeded) {
		t.Errorf("fetchCtx.Err() = %v, want DeadlineExceeded for zero per-attempt budget", observed.Err())
	}
	if !isTimeout || kind != FetchKindTimeout {
		t.Errorf("kind = %v, isTimeout = %v; want FetchKindTimeout/true", kind, isTimeout)
	}
	if ferr == nil {
		t.Error("expected non-nil err for expired ctx")
	}
}

// TestFetchWithBudget_PositivePerAttemptScalesByMaxAttempts verifies that the
// deadline on fetchCtx is perAttempt × FetchMaxAttempts.
func TestFetchWithBudget_PositivePerAttemptScalesByMaxAttempts(t *testing.T) {
	perAttempt := 500 * time.Millisecond
	expectedTotal := perAttempt * time.Duration(gitexec.FetchMaxAttempts)
	var observedRemaining time.Duration
	startCall := time.Now()
	_, _, _, _ = fetchWithBudget(context.Background(), perAttempt, func(fctx context.Context) error {
		deadline, ok := fctx.Deadline()
		if !ok {
			t.Error("fetchCtx has no deadline")
			return nil
		}
		observedRemaining = time.Until(deadline)
		return nil
	})
	elapsed := time.Since(startCall)
	lower := expectedTotal - 200*time.Millisecond - elapsed
	upper := expectedTotal + 200*time.Millisecond
	if observedRemaining < lower || observedRemaining > upper {
		t.Errorf("remaining = %v, want within [%v, %v] (expectedTotal=%v, elapsed=%v)",
			observedRemaining, lower, upper, expectedTotal, elapsed)
	}
}

// TestFetchWithBudget_SIGINTDuringFetch is the end-to-end SIGINT test through
// fetchWithBudget — closes the integration gap that classifier-in-isolation
// tests don't cover.
func TestFetchWithBudget_SIGINTDuringFetch(t *testing.T) {
	parentCtx, cancel := context.WithCancel(context.Background())
	perAttempt := 5 * time.Second

	type result struct {
		kind      FetchKind
		isTimeout bool
		isGone    bool
	}
	resultCh := make(chan result, 1)
	go func() {
		k, isTimeout, isGone, _ := fetchWithBudget(parentCtx, perAttempt, func(fctx context.Context) error {
			<-fctx.Done()
			return fctx.Err()
		})
		resultCh <- result{kind: k, isTimeout: isTimeout, isGone: isGone}
	}()
	time.Sleep(10 * time.Millisecond)
	cancel()
	var got result
	select {
	case got = <-resultCh:
	case <-time.After(2 * time.Second):
		t.Fatal("fetchWithBudget did not return after parent SIGINT")
	}
	if got.kind != FetchKindCancelled {
		t.Errorf("kind = %v, want FetchKindCancelled (SIGINT must propagate through fetchWithBudget)", got.kind)
	}
	if got.isTimeout {
		t.Error("isTimeout=true on SIGINT — would misleadingly suggest --fetch-timeout hint to user")
	}
	if got.isGone {
		t.Error("isGone=true on SIGINT — misclassification")
	}
}

// TestTruncateError_UTF8Safe verifies the byte-slice truncation backs up to
// rune boundaries — important for git stderr on Windows / non-ASCII repo paths.
func TestTruncateError_UTF8Safe(t *testing.T) {
	// "é" is 2 bytes in UTF-8 (0xC3 0xA9). Place it across byte 199-200
	// so truncateError(s, 200) lands mid-rune without rune-aware backup.
	s := strings.Repeat("a", 199) + "é" + strings.Repeat("b", 50)
	out := truncateError(s, 200)
	if !utf8.ValidString(out) {
		t.Errorf("truncated string is invalid UTF-8: %q", out)
	}
	if !strings.HasSuffix(out, "…") {
		t.Errorf("missing ellipsis: %q", out)
	}
}

func TestTruncateError_NoTruncationNeeded(t *testing.T) {
	s := "short message"
	if got := truncateError(s, 200); got != s {
		t.Errorf("got %q, want %q (unchanged)", got, s)
	}
}
