// policy validates a policy locally, or publishes it with a revision precondition.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"cloud.google.com/go/firestore"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/entaku0818/voiceyourtext-voicevox/internal/policy"
)

func main() {
	file := flag.String("file", "internal/policy/default.json", "policy JSON file")
	project := flag.String("project", "", "explicit GCP project (required for publish)")
	document := flag.String("document", "tts_policy/current", "server-only Firestore document")
	expected := flag.String("expect-revision", "", "current revision; 'absent' for initial creation")
	publish := flag.Bool("publish", false, "write to Firestore; omitted means local validation only")
	flag.Parse()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	p, err := (policy.File{Path: *file}).Load(ctx)
	if err != nil {
		log.Fatal(err)
	}
	if !*publish {
		if err := json.NewEncoder(os.Stdout).Encode(p.Public()); err != nil {
			log.Fatal(err)
		}
		return
	}
	if *project == "" || *expected == "" || !policy.ValidDocumentPath(*document) {
		log.Fatal("publish requires -project, -expect-revision and a valid document path")
	}
	if p.Revision == "absent" || p.Revision == *expected {
		log.Fatal("use a new revision for every update")
	}
	client, err := firestore.NewClient(ctx, *project)
	if err != nil {
		log.Fatal(err)
	}
	defer client.Close()
	data, err := json.Marshal(p)
	if err != nil {
		log.Fatal(err)
	}
	ref := client.Doc(*document)
	err = client.RunTransaction(ctx, func(ctx context.Context, tx *firestore.Transaction) error {
		snap, err := tx.Get(ref)
		if status.Code(err) == codes.NotFound {
			if *expected != "absent" {
				return fmt.Errorf("current policy is missing")
			}
		} else {
			if err != nil {
				return err
			}
			previous, ok := snap.Data()["json"].(string)
			if !ok {
				return fmt.Errorf("current policy json is missing")
			}
			old, err := policy.Decode([]byte(previous))
			if err != nil {
				return fmt.Errorf("current policy is invalid: %w", err)
			}
			if old.Revision != *expected {
				return fmt.Errorf("revision changed: expected %s, found %s", *expected, old.Revision)
			}
		}
		// Immutable history prevents accidentally reusing an old revision.
		if err := tx.Create(ref.Collection("revisions").Doc(p.Revision), map[string]any{
			"json": string(data), "createdAt": firestore.ServerTimestamp,
		}); err != nil {
			return err
		}
		return tx.Set(ref, map[string]any{"json": string(data), "updatedAt": firestore.ServerTimestamp})
	})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Published %s to %s/%s\n", p.Revision, *project, *document)
}
