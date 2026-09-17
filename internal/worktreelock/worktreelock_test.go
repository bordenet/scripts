package worktreelock

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// TestRegistry_SameKeyReturnsSameChannel verifies the identity guarantee two
// callers depend on: passing the same key must yield the same channel
// pointer every time, from any goroutine, or serialization silently breaks
// (two different channels for the same repo would let both callers "acquire
// the lock" simultaneously).
func TestRegistry_SameKeyReturnsSameChannel(t *testing.T) {
	var r Registry

	const n = 50
	var wg sync.WaitGroup
	chans := make([]chan struct{}, n)
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			chans[i] = r.Get("shared-key")
		}(i)
	}
	wg.Wait()

	first := chans[0]
	for i, c := range chans {
		if c != first {
			t.Fatalf("chans[%d] != chans[0]: got a distinct channel for the same key under concurrent access", i)
		}
	}
}

// TestRegistry_DifferentKeysReturnDifferentChannels verifies unrelated repos
// never contend on the same lock.
func TestRegistry_DifferentKeysReturnDifferentChannels(t *testing.T) {
	var r Registry
	a := r.Get("repo-a")
	b := r.Get("repo-b")
	if a == b {
		t.Fatal("distinct keys returned the same channel -- unrelated repos would serialize against each other")
	}
}

// TestRegistry_SerializesConcurrentAccess is the actual regression test for
// the bug this package exists to fix: two "workers" sharing a key must never
// be inside their critical section at the same time, even under a tight
// race. Uses an atomic counter + Sleep rather than t.Parallel, since the
// property under test is mutual exclusion at the exact moment of overlap.
func TestRegistry_SerializesConcurrentAccess(t *testing.T) {
	var r Registry
	lock := r.Get("same-repo")

	var inCriticalSection int32
	var overlapDetected int32
	var wg sync.WaitGroup

	const workers = 8
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			lock <- struct{}{}
			defer func() { <-lock }()

			if !atomic.CompareAndSwapInt32(&inCriticalSection, 0, 1) {
				atomic.StoreInt32(&overlapDetected, 1)
			}
			time.Sleep(2 * time.Millisecond)
			atomic.StoreInt32(&inCriticalSection, 0)
		}()
	}
	wg.Wait()

	if atomic.LoadInt32(&overlapDetected) != 0 {
		t.Fatal("two goroutines were inside the critical section for the same key simultaneously -- lock did not serialize access")
	}
}
