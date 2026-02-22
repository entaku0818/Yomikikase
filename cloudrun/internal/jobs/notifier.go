package jobs

import (
	"context"
	"fmt"

	"firebase.google.com/go/v4/messaging"
)

// FCMNotifier is the FCM-backed implementation of Notifier.
type FCMNotifier struct {
	client *messaging.Client
}

// NewFCMNotifier creates an FCMNotifier with the given messaging client.
func NewFCMNotifier(client *messaging.Client) *FCMNotifier {
	return &FCMNotifier{client: client}
}

func (n *FCMNotifier) Send(ctx context.Context, deviceToken, title, body string, data map[string]string) error {
	msg := &messaging.Message{
		Token: deviceToken,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	_, err := n.client.Send(ctx, msg)
	if err != nil {
		return fmt.Errorf("FCM send to %s: %w", deviceToken, err)
	}
	return nil
}
