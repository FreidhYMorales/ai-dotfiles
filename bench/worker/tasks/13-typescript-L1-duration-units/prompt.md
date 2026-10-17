Extend `parseDuration` in `src/duration.ts` with two more units: `d` (days)
and `ms` (milliseconds). They combine with the existing ones like the others
do, for example `1d12h`, `250ms` and `1m30s500ms`, and `5ms` means 5
milliseconds, not 5 minutes and something. Input that is not a sequence of
`<integer><unit>` parts must still throw. `formatDuration` stays as it is.

Add tests for the new units to `test/duration.test.ts`, then run `node --test`
and make sure every test passes. Change only those two files.
