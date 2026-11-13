package quota

import (
	"context"
	"errors"
	"math"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestCorruptCountersFailClosed(t *testing.T) {
	for _, value := range []any{nil, "10", float64(10), int64(-1)} {
		if _, err := decodeChars(value); err == nil {
			t.Fatalf("accepted %v", value)
		}
	}
	if n, err := decodeChars(int64(123)); err != nil || n != 123 {
		t.Fatal(n, err)
	}
	if n, err := readChars(nil, status.Error(codes.NotFound, "missing")); err != nil || n != 0 {
		t.Fatal(n, err)
	}
	if _, err := readChars(nil, status.Error(codes.PermissionDenied, "blocked")); err == nil {
		t.Fatal("read error treated as empty")
	}
}

func TestConcurrentReservationsCannotExceedQuota(t *testing.T) {
	m := &Memory{}
	ctx := context.Background()
	now := time.Now()
	var successes atomic.Int32
	var wg sync.WaitGroup
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := m.Reserve(ctx, "u", 3, 10, now)
			if err == nil {
				successes.Add(1)
			} else if !errors.Is(err, ErrExceeded) {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	u, _ := m.Get(ctx, "u", 10, now)
	if successes.Load() != 3 || u.Used != 9 {
		t.Fatal(successes.Load(), u)
	}
	if err := m.Refund(ctx, "u", 10, now); err == nil {
		t.Fatal("over-refund accepted")
	}
	if _, err := m.Reserve(ctx, "u", math.MaxInt, math.MaxInt, now); !errors.Is(err, ErrExceeded) {
		t.Fatal("overflow accepted", err)
	}
	if err := m.Refund(ctx, "u", 3, now); err != nil {
		t.Fatal(err)
	}
	if u, _ := m.Get(ctx, "u", 10, now); u.Used != 6 {
		t.Fatal(u)
	}
}
