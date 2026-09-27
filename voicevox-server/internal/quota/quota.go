// Package quota は、利用者ごとの月の読み上げ文字数を数える。
package quota

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// ErrExceeded は今月の上限を超える要求。
var ErrExceeded = errors.New("monthly character quota exceeded")

// Usage は今月の利用状況。
type Usage struct {
	Used    int       `json:"used"`
	Limit   int       `json:"limit"`
	ResetAt time.Time `json:"resetAt"`
}

// Store は月の文字数を予約・返却する。
type Store interface {
	// Reserve は chars 文字を今月分に加える。上限を超えるなら何も加えず ErrExceeded を返す。
	Reserve(ctx context.Context, userID string, chars, limit int, now time.Time) (Usage, error)
	// Refund は合成に失敗した分を戻す。
	Refund(ctx context.Context, userID string, chars int, now time.Time) error
	// Get は今月の使用量を返す。
	Get(ctx context.Context, userID string, limit int, now time.Time) (Usage, error)
}

// 月の区切りは日本時間。アプリの利用者の7割が日本なので、月初の0時に戻るほうが分かりやすい。
var jst = time.FixedZone("JST", 9*60*60)

func monthKey(now time.Time) string {
	return now.In(jst).Format("2006-01")
}

func resetAt(now time.Time) time.Time {
	t := now.In(jst)
	return time.Date(t.Year(), t.Month()+1, 1, 0, 0, 0, 0, jst)
}

// Firestore は voicevox_usage/{userID}_{YYYY-MM} に文字数を持つ。
type Firestore struct {
	Client     *firestore.Client
	Collection string
}

func (f Firestore) doc(userID string, now time.Time) *firestore.DocumentRef {
	col := f.Collection
	if col == "" {
		col = "voicevox_usage"
	}
	return f.Client.Collection(col).Doc(fmt.Sprintf("%s_%s", userID, monthKey(now)))
}

// Reserve はトランザクションで上限を確認してから加算する。
func (f Firestore) Reserve(ctx context.Context, userID string, chars, limit int, now time.Time) (Usage, error) {
	ref := f.doc(userID, now)
	var used int
	err := f.Client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		current, err := readChars(tx.Get(ref))
		if err != nil {
			return err
		}
		if current+chars > limit {
			used = current
			return ErrExceeded
		}
		used = current + chars
		return tx.Set(ref, map[string]any{
			"userId":    userID,
			"month":     monthKey(now),
			"chars":     used,
			"updatedAt": now,
		}, firestore.MergeAll)
	})
	usage := Usage{Used: used, Limit: limit, ResetAt: resetAt(now)}
	if errors.Is(err, ErrExceeded) {
		return usage, ErrExceeded
	}
	return usage, err
}

// Refund は加算した分を差し引く。
func (f Firestore) Refund(ctx context.Context, userID string, chars int, now time.Time) error {
	_, err := f.doc(userID, now).Update(ctx, []firestore.Update{
		{Path: "chars", Value: firestore.Increment(-chars)},
	})
	return err
}

// Get は今月の使用量を読む。
func (f Firestore) Get(ctx context.Context, userID string, limit int, now time.Time) (Usage, error) {
	used, err := readChars(f.doc(userID, now).Get(ctx))
	return Usage{Used: used, Limit: limit, ResetAt: resetAt(now)}, err
}

func readChars(snap *firestore.DocumentSnapshot, err error) (int, error) {
	if status.Code(err) == codes.NotFound {
		return 0, nil
	}
	if err != nil {
		return 0, err
	}
	v, err := snap.DataAt("chars")
	if err != nil {
		return 0, nil
	}
	n, _ := v.(int64)
	return int(n), nil
}

// Memory はテスト・ローカル開発用。
type Memory struct {
	mu   sync.Mutex
	used map[string]int
}

func (m *Memory) key(userID string, now time.Time) string {
	if m.used == nil {
		m.used = map[string]int{}
	}
	return userID + "_" + monthKey(now)
}

// Reserve は上限を確認してから加算する。
func (m *Memory) Reserve(_ context.Context, userID string, chars, limit int, now time.Time) (Usage, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	k := m.key(userID, now)
	if m.used[k]+chars > limit {
		return Usage{Used: m.used[k], Limit: limit, ResetAt: resetAt(now)}, ErrExceeded
	}
	m.used[k] += chars
	return Usage{Used: m.used[k], Limit: limit, ResetAt: resetAt(now)}, nil
}

// Refund は差し引く。
func (m *Memory) Refund(_ context.Context, userID string, chars int, now time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.used[m.key(userID, now)] -= chars
	return nil
}

// Get は使用量を返す。
func (m *Memory) Get(_ context.Context, userID string, limit int, now time.Time) (Usage, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return Usage{Used: m.used[m.key(userID, now)], Limit: limit, ResetAt: resetAt(now)}, nil
}
