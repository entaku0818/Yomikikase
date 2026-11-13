package entitlement

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestConcurrentLookupsShareOneFetchAndExpire(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		fmt.Fprint(w, `{"items":[{"entitlement_id":"premium"}]}`)
	}))
	defer srv.Close()
	r := &RevenueCat{BaseURL: srv.URL, ProjectID: "p", EntitlementID: "premium"}
	var wg sync.WaitGroup
	for i := 0; i < 64; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			got, err := r.IsPremium(context.Background(), "u")
			if err != nil || !got {
				t.Error(got, err)
			}
		}()
	}
	wg.Wait()
	if calls.Load() != 1 {
		t.Fatalf("calls=%d", calls.Load())
	}
	r.mu.Lock()
	r.cache["u"] = cached{premium: true, until: time.Now().Add(-time.Second)}
	r.mu.Unlock()
	if _, err := r.IsPremium(context.Background(), "u"); err != nil || calls.Load() != 2 {
		t.Fatalf("expired calls=%d err=%v", calls.Load(), err)
	}
}

func TestCacheRemainsBoundedUnderIdentifierChurn(t *testing.T) {
	r := &RevenueCat{}
	for i := 0; i < maxCachedCustomers+100; i++ {
		r.remember(fmt.Sprint(i), false)
	}
	if len(r.cache) != maxCachedCustomers {
		t.Fatal(len(r.cache))
	}
	for id := range r.cache {
		r.cache[id] = cached{until: time.Now().Add(-time.Second)}
	}
	r.remember("new", true)
	if len(r.cache) != 1 {
		t.Fatalf("expired entries retained: %d", len(r.cache))
	}
}

func TestOversizedOrInvalidResponsesCannotGrantPremium(t *testing.T) {
	for _, body := range []string{strings.Repeat(" ", maxResponseBytes+1), `{"items":[{"entitlement_id":"premium"}]} garbage`} {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { fmt.Fprint(w, body) }))
		r := &RevenueCat{BaseURL: srv.URL, EntitlementID: "premium"}
		premium, err := r.IsPremium(context.Background(), "u")
		srv.Close()
		if err == nil || premium || len(r.cache) != 0 {
			t.Fatal("invalid response trusted or cached")
		}
	}
}
