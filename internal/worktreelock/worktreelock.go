// Package worktreelock provides a keyed registry of channel-based locks used
// to serialize concurrent access to git repos that share a common git
// directory (git worktrees of the same physical repo).
//
// All worktrees of one repo share refs/remotes/origin/* and the object store
// even though each has its own HEAD, index, and working files. Running
// `git fetch` against two such worktrees concurrently races on git's
// ref-lock and fails intermittently ("cannot lock ref ... is at X but
// expected Y"). Keying a lock by the repo's common git directory (see
// gitexec.CommonGitDir) and acquiring it before syncing each discovered path
// closes that race without serializing unrelated repos against each other.
package worktreelock

import "sync"

// Registry hands out one lock channel per key, creating it on first use and
// reusing the same channel for every subsequent call with that key. The zero
// value is ready to use.
type Registry struct {
	mu    sync.Mutex
	locks map[string]chan struct{}
}

// Get returns the lock channel for key, creating a new one (capacity 1, so it
// can be used as a mutex via `ch <- struct{}{}` / `<-ch`) if this is the
// first time key has been seen. The returned channel is stable across calls
// with the same key: two callers passing the same key always get the same
// channel pointer, which is what makes it useful for serializing access.
//
// An empty key is treated like any other string key -- callers that want "no
// lock" for unknown/undeterminable keys should check for that condition
// themselves before calling Get (see gitexec.CommonGitDir's "" convention)
// rather than relying on Get to special-case it, since a shared "" key would
// incorrectly serialize every repo whose common dir couldn't be determined
// against every other such repo.
func (r *Registry) Get(key string) chan struct{} {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.locks == nil {
		r.locks = make(map[string]chan struct{})
	}
	if l, ok := r.locks[key]; ok {
		return l
	}
	l := make(chan struct{}, 1)
	r.locks[key] = l
	return l
}
