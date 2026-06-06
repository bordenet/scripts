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
	// success path and classifyFetchError isn't called for it. Listing the
	// kinds explicitly here (rather than deriving from `int(FetchKindRepoGone)`)
	// keeps the contract robust to enum reordering or insertion of new
	// values — a new kind must be added to BOTH this slice and the setups
	// table for the test to compile and pass.
	requiredKinds := []FetchKind{
		FetchKindTimeout,
		FetchKindCancelled,
		FetchKindTransientGaveUp,
		FetchKindRepoGone,
	}
	seen := map[FetchKind]bool{}
	for _, c := range setups {
		seen[c.wantKind] = true
	}
	for _, k := range requiredKinds {
		if !seen[k] {
			t.Fatalf("setups missing coverage for %v — add a case", k)
		}
	}
	if len(seen) != len(requiredKinds) {
		t.Fatalf("setups cover %d kinds, want exactly %d (no extras, no missing)", len(seen), len(requiredKinds))
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
// TestClassifyFetchError_CancelBeforeDeadlineWins models the real production
// path: a parent ctx with a deadline gets cancel()ed (SIGINT propagation)
// BEFORE the deadline elapses. Per Go semantics, Canceled wins because it
// is the first error set on the ctx. The classifier MUST return Cancelled.
func TestClassifyFetchError_CancelBeforeDeadlineWins(t *testing.T) {
	parentCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	cancel() // fires immediately, before the 10s deadline
	kind, isTimeout, _ := classifyFetchError(parentCtx, parentCtx, context.Canceled)
	if kind != FetchKindCancelled {
		t.Errorf("kind = %v, want FetchKindCancelled (cancel before deadline = SIGINT semantics)", kind)
	}
	if isTimeout {
		t.Error("isTimeout must be false for Cancelled kind")
	}
}

// TestFetchWithBudget_ZeroPerAttemptYieldsExpiredCtx pins the test-injection
// pattern where FetchTimeout=0 produces an immediately-expired fetchCtx.
// CLI users cannot reach this state (parseFlags rejects <1); only the
// internal Flags struct accepts 0 for test purposes.
func TestFetchWithBudget_ZeroPerAttemptYieldsExpiredCtx(t *testing.T) {
	var observed context.Context
	kind, ferr := fetchWithBudget(context.Background(), 0, 1, func(fctx context.Context) error {
		observed = fctx
		return fctx.Err()
	})
	if observed == nil {
		t.Fatal("lambda not invoked")
	}
	if !errors.Is(observed.Err(), context.DeadlineExceeded) {
		t.Errorf("fetchCtx.Err() = %v, want DeadlineExceeded for zero per-attempt budget", observed.Err())
	}
	if kind != FetchKindTimeout {
		t.Errorf("kind = %v; want FetchKindTimeout", kind)
	}
	if ferr == nil {
		t.Error("expected non-nil err for expired ctx")
	}
}

// TestFetchWithBudget_PositivePerAttemptScalesByMaxAttempts verifies that the
// deadline on fetchCtx is perAttempt × FetchMaxAttempts × refCount.
func TestFetchWithBudget_PositivePerAttemptScalesByMaxAttempts(t *testing.T) {
	perAttempt := 500 * time.Millisecond
	refCount := 1
	expectedTotal := perAttempt * time.Duration(gitexec.FetchMaxAttempts) * time.Duration(refCount)
	var observedRemaining time.Duration
	startCall := time.Now()
	_, _ = fetchWithBudget(context.Background(), perAttempt, refCount, func(fctx context.Context) error {
		deadline, ok := fctx.Deadline()
		if !ok {
			t.Error("fetchCtx has no deadline")
			return nil
		}
		observedRemaining = time.Until(deadline)
		return nil
	})
	elapsed := time.Since(startCall)
	// ±500ms slack to absorb scheduling jitter on loaded CI runners (macOS GHA
	// has been observed to drift >200ms on sleep precision). The point of this
	// test is that "budget scales by FetchMaxAttempts" — sub-millisecond
	// precision is not what we're measuring.
	lower := expectedTotal - 500*time.Millisecond - elapsed
	upper := expectedTotal + 500*time.Millisecond
	if observedRemaining < lower || observedRemaining > upper {
		t.Errorf("remaining = %v, want within [%v, %v] (expectedTotal=%v, elapsed=%v)",
			observedRemaining, lower, upper, expectedTotal, elapsed)
	}
}

// TestFetchWithBudget_RefCountScalesTotal verifies that refCount>1 multiplies
// the total budget, giving each ref a fair share when called with a multi-ref
// caller like FetchMultiRef.
func TestFetchWithBudget_RefCountScalesTotal(t *testing.T) {
	perAttempt := 200 * time.Millisecond
	refCount := 5
	expectedTotal := perAttempt * time.Duration(gitexec.FetchMaxAttempts) * time.Duration(refCount)
	var observedRemaining time.Duration
	startCall := time.Now()
	_, _ = fetchWithBudget(context.Background(), perAttempt, refCount, func(fctx context.Context) error {
		deadline, _ := fctx.Deadline()
		observedRemaining = time.Until(deadline)
		return nil
	})
	elapsed := time.Since(startCall)
	lower := expectedTotal - 500*time.Millisecond - elapsed
	upper := expectedTotal + 500*time.Millisecond
	if observedRemaining < lower || observedRemaining > upper {
		t.Errorf("remaining = %v, want within [%v, %v] for refCount=%d", observedRemaining, lower, upper, refCount)
	}
}

// TestFetchWithBudget_RefCountFloorsToOne ensures refCount<1 is normalized
// to 1 — defensive against caller bugs that pass len() of an empty slice.
func TestFetchWithBudget_RefCountFloorsToOne(t *testing.T) {
	perAttempt := 100 * time.Millisecond
	expectedTotal := perAttempt * time.Duration(gitexec.FetchMaxAttempts) // refCount=1 floor
	var observedRemaining time.Duration
	_, _ = fetchWithBudget(context.Background(), perAttempt, 0, func(fctx context.Context) error {
		deadline, _ := fctx.Deadline()
		observedRemaining = time.Until(deadline)
		return nil
	})
	if observedRemaining > expectedTotal+500*time.Millisecond || observedRemaining < expectedTotal-500*time.Millisecond {
		t.Errorf("refCount=0 not floored to 1: remaining = %v, want ~%v", observedRemaining, expectedTotal)
	}
}

// TestFetchWithBudget_SIGINTDuringFetch is the end-to-end SIGINT test through
// fetchWithBudget — closes the integration gap that classifier-in-isolation
// tests don't cover.
func TestFetchWithBudget_SIGINTDuringFetch(t *testing.T) {
	parentCtx, cancel := context.WithCancel(context.Background())
	perAttempt := 5 * time.Second

	resultCh := make(chan FetchKind, 1)
	entered := make(chan struct{})
	go func() {
		k, _ := fetchWithBudget(parentCtx, perAttempt, 1, func(fctx context.Context) error {
			close(entered) // deterministic: signal we're in the lambda
			<-fctx.Done()
			return fctx.Err()
		})
		resultCh <- k
	}()
	<-entered // wait for goroutine to enter lambda — no sleep-based heuristic
	cancel()
	var got FetchKind
	select {
	case got = <-resultCh:
	case <-time.After(2 * time.Second):
		t.Fatal("fetchWithBudget did not return after parent SIGINT")
	}
	if got != FetchKindCancelled {
		t.Errorf("kind = %v, want FetchKindCancelled (SIGINT must propagate through fetchWithBudget)", got)
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

// TestTruncateError_StripsNewlines verifies the single-line contract: git
// stderr contains "\n"-separated lines, and the formatter renders one line
// per repo. Embedded newlines would break the layout.
func TestTruncateError_StripsNewlines(t *testing.T) {
	s := "error: line 1\nfatal: line 2\r\nfatal: line 3"
	got := truncateError(s, 200)
	if strings.Contains(got, "\n") || strings.Contains(got, "\r") {
		t.Errorf("newlines not stripped: %q", got)
	}
	for _, want := range []string{"line 1", "line 2", "line 3", "|"} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in %q", want, got)
		}
	}
}

// TestIsUntrackedConflictError verifies the classifier for the specific
// git error `pull --ff-only` returns when untracked working-tree files
// would be overwritten. Commonly seen on workstations that receive files
// via OneDrive / sibling-clone sync.
func TestIsUntrackedConflictError(t *testing.T) {
	cases := []struct {
		name string
		msg  string
		want bool
	}{
		{
			name: "real git stderr from pull --ff-only",
			msg:  "git pull --ff-only origin main: exit status 1 (stderr: From https://x\n * branch main -> FETCH_HEAD\nerror: The following untracked working tree files would be overwritten by merge:\n    internal/gitexec/gitexec_test.go\nPlease move or remove them before you merge.\nAborting)",
			want: true,
		},
		{
			name: "case insensitive",
			msg:  "Untracked Working Tree Files Would Be Overwritten",
			want: true,
		},
		{
			name: "merge conflict (different error class)",
			msg:  "error: Merge conflict in foo.txt",
			want: false,
		},
		{
			name: "ff-only refused (non-ff)",
			msg:  "fatal: Not possible to fast-forward, aborting.",
			want: false,
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := fmt.Errorf("%s", tc.msg)
			if got := isUntrackedConflictError(err); got != tc.want {
				t.Errorf("got %v, want %v", got, tc.want)
			}
		})
	}
	if isUntrackedConflictError(nil) {
		t.Error("isUntrackedConflictError(nil) should return false")
	}
}

// TestShellQuotePath covers the POSIX-shell quoting helper used by
// execute.go when building ManualSteps. Any path output as part of a
// copy-pasteable command MUST go through this helper so that paths with
// shell metacharacters cannot be accidentally evaluated.
func TestShellQuotePath(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"/tmp/repo", "'/tmp/repo'"},
		{"/path with spaces/x", "'/path with spaces/x'"},
		{"/has$dollar", "'/has$dollar'"},
		{"/has;semi", "'/has;semi'"},
		{"/has`backtick`", "'/has`backtick`'"},
		{"/has*star", "'/has*star'"},
		{"/it's/got/quote", `'/it'\''s/got/quote'`},
	}
	for _, tc := range cases {
		t.Run(tc.in, func(t *testing.T) {
			if got := shellQuotePath(tc.in); got != tc.want {
				t.Errorf("shellQuotePath(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}
