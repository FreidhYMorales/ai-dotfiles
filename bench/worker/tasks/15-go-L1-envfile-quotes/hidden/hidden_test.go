package envfile

import (
	"strings"
	"testing"
)

func TestHiddenQuoted(t *testing.T) {
	cases := map[string]string{
		`A="hello world"`:         "hello world",
		`A="x # y"`:               "x # y",
		`A = "  padded  "  `:      "  padded  ",
		`A=""`:                    "",
		`A="say \"hi\""`:          `say "hi"`,
		`A="back\\slash"`:         `back\slash`,
		`A="two\nlines"`:          "two\nlines",
		`A="v" # trailing note`:   "v",
		`A="a=b"`:                 "a=b",
		`A=plain # not a comment`: "plain # not a comment",
		`A=say"hi"`:               `say"hi"`,
		`A='single'`:              `'single'`,
	}
	for line, want := range cases {
		vars, err := Parse(strings.NewReader("X=1\n" + line + "\n"))
		if err != nil {
			t.Errorf("%s: unexpected error %v", line, err)
			continue
		}
		if vars["A"] != want {
			t.Errorf("%s: got %q, want %q", line, vars["A"], want)
		}
		if vars["X"] != "1" {
			t.Errorf("%s: X = %q", line, vars["X"])
		}
	}
}

func TestHiddenQuotedErrors(t *testing.T) {
	for _, line := range []string{
		`A="unterminated`,
		`A="bad \t escape"`,
		`A="x" junk`,
		`A="x"y`,
		`A="ends with backslash\"`,
	} {
		_, err := Parse(strings.NewReader("X=1\n" + line + "\n"))
		if err == nil || !strings.Contains(err.Error(), "line 2") {
			t.Errorf("%s: error = %v, want one naming line 2", line, err)
		}
	}
}
