#!/usr/bin/env bash
# A tiny Go module with one pure function and no tests yet.
set -eu
mkdir -p slug
cat >go.mod <<'MOD'
module example.com/slug

go 1.22
MOD
cat >slug/slug.go <<'GO'
package slug

import (
	"strings"
	"unicode"
)

// Slugify lowercases s and joins its letter/digit runs with single dashes.
func Slugify(s string) string {
	var b strings.Builder
	dash := false
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			if dash && b.Len() > 0 {
				b.WriteByte('-')
			}
			b.WriteRune(r)
			dash = false
			continue
		}
		dash = true
	}
	return b.String()
}
GO
