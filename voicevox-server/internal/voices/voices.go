// Package voices defines the server-owned character catalog. The actual entries
// live in the policy JSON; adding a character never requires an app release.
package voices

import (
	"errors"
	"net/url"
	"strings"
	"unicode/utf8"
)

type Voice struct {
	SpeakerID int    `json:"speakerId"`
	Character string `json:"character"`
	Style     string `json:"style"`
	Credit    string `json:"credit"`
	TermsURL  string `json:"termsUrl"`
	Enabled   bool   `json:"enabled"`
}

type Catalog struct {
	DefaultSpeakerID *int    `json:"defaultSpeakerId"`
	TermsURL         string  `json:"termsUrl"`
	Voices           []Voice `json:"voices"`
}

func httpsURL(raw string) bool {
	u, err := url.Parse(raw)
	return err == nil && u.Scheme == "https" && u.Hostname() != "" && u.User == nil && len(raw) <= 2048
}

func (c Catalog) Validate() error {
	if !httpsURL(c.TermsURL) || len(c.Voices) > 128 {
		return errors.New("invalid catalog")
	}
	seen := map[int]bool{}
	active := 0
	for _, v := range c.Voices {
		if v.SpeakerID < 0 || seen[v.SpeakerID] || strings.TrimSpace(v.Character) == "" || strings.TrimSpace(v.Style) == "" || strings.TrimSpace(v.Credit) == "" || !httpsURL(v.TermsURL) || utf8.RuneCountInString(v.Character) > 100 || utf8.RuneCountInString(v.Style) > 100 || utf8.RuneCountInString(v.Credit) > 300 {
			return errors.New("invalid or duplicate character")
		}
		seen[v.SpeakerID] = true
		if v.Enabled {
			active++
		}
	}
	if active == 0 {
		if c.DefaultSpeakerID != nil {
			return errors.New("empty catalog must not have a default")
		}
	} else {
		if c.DefaultSpeakerID == nil {
			return errors.New("catalog default is missing")
		}
		if _, ok := c.Find(*c.DefaultSpeakerID); !ok {
			return errors.New("catalog default is not enabled")
		}
	}
	return nil
}

func (c Catalog) Find(speakerID int) (Voice, bool) {
	for _, v := range c.Voices {
		if v.SpeakerID == speakerID && v.Enabled {
			return v, true
		}
	}
	return Voice{}, false
}

// Disabled characters retain their attribution, but cannot be newly generated.
type Response struct {
	SchemaVersion    int     `json:"schemaVersion"`
	Revision         string  `json:"revision"`
	DefaultSpeakerID *int    `json:"defaultSpeakerId"`
	TermsURL         string  `json:"termsUrl"`
	Voices           []Voice `json:"voices"`
	Credits          []Voice `json:"credits"`
}

func (c Catalog) Public(revision string, generationEnabled bool) Response {
	active := []Voice{}
	for _, v := range c.Voices {
		if generationEnabled && v.Enabled {
			active = append(active, v)
		}
	}
	defaultID := c.DefaultSpeakerID
	if !generationEnabled {
		defaultID = nil
	}
	credits := append([]Voice{}, c.Voices...)
	return Response{1, revision, defaultID, c.TermsURL, active, credits}
}
