// Package envfile parses .env files: one KEY=VALUE per line, blank lines and
// lines starting with # ignored, whitespace around keys and values trimmed.
package envfile

import (
	"bufio"
	"fmt"
	"io"
	"regexp"
	"strings"
)

var validKey = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

// Parse reads r and returns its variables. A later assignment to the same key
// wins. Errors name the 1-based line number.
func Parse(r io.Reader) (map[string]string, error) {
	vars := map[string]string{}
	sc := bufio.NewScanner(r)
	n := 0
	for sc.Scan() {
		n++
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			return nil, fmt.Errorf("line %d: missing '='", n)
		}
		key = strings.TrimSpace(key)
		if !validKey.MatchString(key) {
			return nil, fmt.Errorf("line %d: invalid key %q", n, key)
		}
		v, err := parseValue(strings.TrimSpace(value))
		if err != nil {
			return nil, fmt.Errorf("line %d: %w", n, err)
		}
		vars[key] = v
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return vars, nil
}

// parseValue turns the raw text after '=' into the variable's value.
func parseValue(raw string) (string, error) {
	return raw, nil
}
