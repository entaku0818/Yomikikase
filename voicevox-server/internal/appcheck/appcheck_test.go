package appcheck

import (
	"context"
	"errors"
	firebasecheck "firebase.google.com/go/v4/appcheck"
	"testing"
)

type tokenStub struct {
	id  string
	err error
}

func (s tokenStub) VerifyToken(string) (*firebasecheck.DecodedAppCheckToken, error) {
	return &firebasecheck.DecodedAppCheckToken{AppID: s.id}, s.err
}

func TestAllowedAppIsRequiredAfterSDKVerification(t *testing.T) {
	for _, tc := range []struct {
		id      string
		err     error
		allowed bool
	}{
		{"ios", nil, true}, {"android", nil, true}, {"other-app", nil, false},
		{"ios", errors.New("invalid signature or expired token"), false},
	} {
		v := Verifier{Client: tokenStub{tc.id, tc.err}, AllowedAppIDs: []string{"ios", "android"}}
		if err := v.Verify(context.Background(), "token"); (err == nil) != tc.allowed {
			t.Fatalf("%s allowed=%v err=%v", tc.id, tc.allowed, err)
		}
	}
}
