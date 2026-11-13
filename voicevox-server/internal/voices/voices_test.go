package voices

import "testing"

func fixture() Catalog {
	id := 401
	return Catalog{DefaultSpeakerID: &id, TermsURL: "https://example.com/terms", Voices: []Voice{
		{SpeakerID: 401, Character: "server voice", Style: "normal", Credit: "test credit", TermsURL: "https://example.com/voice", Enabled: true},
	}}
}

func TestCatalogRejectsInvalidDefaultsDuplicatesAndLinks(t *testing.T) {
	for _, mutate := range []func(*Catalog){
		func(c *Catalog) { c.DefaultSpeakerID = nil },
		func(c *Catalog) { c.Voices[0].Enabled = false },
		func(c *Catalog) { c.Voices = append(c.Voices, c.Voices[0]) },
		func(c *Catalog) { c.Voices[0].TermsURL = "javascript:alert(1)" },
		func(c *Catalog) { c.TermsURL = "http://example.com" },
		func(c *Catalog) { c.Voices[0].Credit = "" },
	} {
		c := fixture()
		mutate(&c)
		if c.Validate() == nil {
			t.Fatal("invalid catalog accepted")
		}
	}
}

func TestDisabledCharactersKeepCreditsButCannotGenerate(t *testing.T) {
	c := fixture()
	c.Voices[0].Enabled = false
	c.DefaultSpeakerID = nil
	if err := c.Validate(); err != nil {
		t.Fatal(err)
	}
	if _, ok := c.Find(401); ok {
		t.Fatal("disabled voice allowed")
	}
	public := c.Public("r2", true)
	if len(public.Voices) != 0 || len(public.Credits) != 1 || public.DefaultSpeakerID != nil {
		t.Fatal(public)
	}
	c = fixture()
	public = c.Public("r3", false)
	if len(public.Voices) != 0 || len(public.Credits) != 1 || public.DefaultSpeakerID != nil {
		t.Fatal(public)
	}
}
