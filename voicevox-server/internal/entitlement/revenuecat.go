// Package entitlement は、利用者がプレミアム会員かを RevenueCat に問い合わせる。
package entitlement

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"

	"golang.org/x/sync/singleflight"
)

const maxCachedCustomers = 4096
const maxResponseBytes = 1 << 20

// Checker はプレミアム会員かを返す。
type Checker interface {
	IsPremium(ctx context.Context, userID string) (bool, error)
}

// RevenueCat は REST API v2 の active_entitlements で判定する。
// 1回の読み上げで文ごとに何度も呼ばれるため、結果を利用者ごとに TTL だけ覚えておく。
type RevenueCat struct {
	SecretKey     string
	ProjectID     string
	EntitlementID string
	TTL           time.Duration
	HTTP          *http.Client
	BaseURL       string

	mu      sync.Mutex
	cache   map[string]cached
	lookups singleflight.Group
}

type cached struct {
	premium bool
	until   time.Time
}

// IsPremium は entitlement が有効なら true。RevenueCat に顧客がいない（404）場合は無料扱い。
func (r *RevenueCat) IsPremium(ctx context.Context, userID string) (bool, error) {
	if premium, ok := r.cachedPremium(userID); ok {
		return premium, nil
	}
	value, err, _ := r.lookups.Do(userID, func() (any, error) {
		if premium, ok := r.cachedPremium(userID); ok {
			return premium, nil
		}
		premium, err := r.fetch(ctx, userID)
		if err != nil {
			return false, err
		}
		r.remember(userID, premium)
		return premium, nil
	})
	if err != nil {
		return false, err
	}
	return value.(bool), nil
}

func (r *RevenueCat) cachedPremium(userID string) (bool, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if c, ok := r.cache[userID]; ok && time.Now().Before(c.until) {
		return c.premium, true
	}
	return false, false
}

func (r *RevenueCat) remember(userID string, premium bool) {
	now := time.Now()
	ttl := r.TTL
	if ttl == 0 {
		ttl = 5 * time.Minute
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.cache == nil {
		r.cache = map[string]cached{}
	}
	if len(r.cache) >= maxCachedCustomers {
		for id, c := range r.cache {
			if !now.Before(c.until) {
				delete(r.cache, id)
			}
		}
		if len(r.cache) >= maxCachedCustomers {
			// Any cached entry can be safely refetched; never grow without a bound.
			for id := range r.cache {
				delete(r.cache, id)
				break
			}
		}
	}
	r.cache[userID] = cached{premium: premium, until: now.Add(ttl)}
}

func (r *RevenueCat) fetch(ctx context.Context, userID string) (bool, error) {
	base := r.BaseURL
	if base == "" {
		base = "https://api.revenuecat.com"
	}
	endpoint := fmt.Sprintf("%s/v2/projects/%s/customers/%s/active_entitlements",
		base, url.PathEscape(r.ProjectID), url.PathEscape(userID))
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("Authorization", "Bearer "+r.SecretKey)

	client := r.HTTP
	if client == nil {
		client = &http.Client{Timeout: 10 * time.Second}
	}
	resp, err := client.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	case http.StatusOK:
	case http.StatusNotFound:
		return false, nil
	default:
		return false, fmt.Errorf("revenuecat returned %d", resp.StatusCode)
	}

	var body struct {
		Items []struct {
			EntitlementID string `json:"entitlement_id"`
			ExpiresAt     *int64 `json:"expires_at"`
		} `json:"items"`
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes+1))
	if err != nil {
		return false, err
	}
	if len(data) > maxResponseBytes {
		return false, fmt.Errorf("revenuecat response too large")
	}
	if err := json.Unmarshal(data, &body); err != nil {
		return false, err
	}
	for _, item := range body.Items {
		if item.EntitlementID == r.EntitlementID {
			return true, nil
		}
	}
	return false, nil
}

// Static はテスト・ローカル開発用。Premium に入っている利用者だけプレミアム扱い。
type Static struct {
	Premium map[string]bool
}

// IsPremium は Premium を引くだけ。
func (s Static) IsPremium(_ context.Context, userID string) (bool, error) {
	return s.Premium[userID], nil
}
