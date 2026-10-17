Add double-quoted values to the `.env` parser in `envfile.go`:

- `KEY="value"` gives `value`; inside the quotes spaces and `#` are kept
  literally (`A="x # y"` gives `x # y`)
- inside the quotes, `\"` is a quote, `\\` is a backslash and `\n` is a
  newline; any other backslash sequence is an error
- after the closing quote only whitespace or a `# comment` may follow;
  anything else is an error, and so is a missing closing quote
- errors name the line like the existing ones (`line N: ...`)
- unquoted values behave exactly as today

Add tests to `envfile_test.go`, then run `go test ./...` and make sure every
test passes (and `go vet ./...` is clean). Change only those two files.
