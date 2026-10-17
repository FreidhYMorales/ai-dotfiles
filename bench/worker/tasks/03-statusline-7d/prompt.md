In `claude/statusline.sh`, also show the 7-day plan quota when the input JSON has
`rate_limits.seven_day.used_percentage`: add a segment `7d N%` right after the
5-hour segment, colored with the same thresholds as the 5-hour quota. Show
nothing for it when the field is absent. Add test cases for both situations in
`scripts/tests/statusline.test.sh`. Then run `make check` and make sure it ends
with "All checks passed". Change only those two files.
