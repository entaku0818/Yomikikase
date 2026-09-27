// Package appcheck は Firebase App Check トークンを検証する。
package appcheck

import (
	"context"
	"fmt"
	"slices"

	"firebase.google.com/go/v4/appcheck"
)

// tokenVerifier は firebase admin の appcheck.Client のうち使う部分。
type tokenVerifier interface {
	VerifyToken(token string) (*appcheck.DecodedAppCheckToken, error)
}

// Verifier は署名・有効期限に加えて、発行先が許可したアプリかを確かめる。
type Verifier struct {
	Client        tokenVerifier
	AllowedAppIDs []string
}

// Verify はトークンが正しく、発行先が AllowedAppIDs のどれかなら nil。
func (v Verifier) Verify(_ context.Context, token string) error {
	decoded, err := v.Client.VerifyToken(token)
	if err != nil {
		return err
	}
	if !slices.Contains(v.AllowedAppIDs, decoded.AppID) {
		return fmt.Errorf("app id %q is not allowed", decoded.AppID)
	}
	return nil
}

// AllowAll は検証しない。LOCAL_DEV でのみ使う。
type AllowAll struct{}

// Verify は常に nil。
func (AllowAll) Verify(context.Context, string) error { return nil }
