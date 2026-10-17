package envfile

import (
	"strings"
	"testing"
)

func parse(t *testing.T, src string) map[string]string {
	t.Helper()
	vars, err := Parse(strings.NewReader(src))
	if err != nil {
		t.Fatalf("Parse: %v", err)
	}
	return vars
}

func TestBasic(t *testing.T) {
	vars := parse(t, "A=1\n  B = two words  \n\n# comment\nC=\n")
	want := map[string]string{"A": "1", "B": "two words", "C": ""}
	if len(vars) != len(want) {
		t.Fatalf("got %v, want %v", vars, want)
	}
	for k, v := range want {
		if vars[k] != v {
			t.Errorf("%s = %q, want %q", k, vars[k], v)
		}
	}
}

func TestLaterWins(t *testing.T) {
	if got := parse(t, "A=1\nA=2\n")["A"]; got != "2" {
		t.Errorf("A = %q, want 2", got)
	}
}

func TestValueKeepsEquals(t *testing.T) {
	if got := parse(t, "URL=postgres://u:p@h/db?x=1\n")["URL"]; got != "postgres://u:p@h/db?x=1" {
		t.Errorf("URL = %q", got)
	}
}

func TestErrorsNameTheLine(t *testing.T) {
	for _, src := range []string{"A=1\nnope\n", "A=1\n1BAD=x\n"} {
		_, err := Parse(strings.NewReader(src))
		if err == nil || !strings.Contains(err.Error(), "line 2") {
			t.Errorf("Parse(%q) error = %v, want line 2", src, err)
		}
	}
}
