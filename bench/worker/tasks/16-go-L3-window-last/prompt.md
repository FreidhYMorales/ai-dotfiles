Bug report for the `window` package (see README.md):

On the status dashboard the "latest latency" tile freezes after a while: once
more samples have been recorded than the window holds, it stops following the
newest sample and keeps showing older values, while the "mean" and "max"
tiles keep updating correctly. Right after a restart it is correct again.

Find the cause and fix it. Add a test that reproduces the problem to
`window_test.go`, then run `go test ./...` and make sure every test passes
(and `go vet ./...` is clean). Change only `window.go` and `window_test.go`.
