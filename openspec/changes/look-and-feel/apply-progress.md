# Apply progress: look-and-feel

## PR 1: Status line (tasks 1.1-1.3) - done

Mode: Strict TDD. Branch: feat/look-statusline.

### TDD Cycle Evidence

| Task | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| 1.1 | 21 new cases failed against the old script (`bash scripts/tests/statusline.test.sh`: "21 case(s) failed") | - | - |
| 1.2 | - | same file: "All cases passed" | - |
| 1.3 | - | `make check`: All checks passed (7 steps) | helpers split into `color`, `bar`, `meter`, `trunc`; README rows updated |

Safety net: 22 pre-existing cases passed before edits.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test | `bash scripts/tests/statusline.test.sh` exit 0, all cases passed |
| Runtime harness | JSON piped into `claude/statusline.sh`, worst case 6-char model: 94 + place visible chars (test budget 110) |
| Rollback boundary | `claude/statusline.sh`, `scripts/tests/statusline.test.sh`, README rows 19 and 115 |

### Notes

- Worst case measured ~106 columns with a 4-char model, over the plan ~100. The test budget is 110. Branch cap 20 excludes the dirty `*`.
- Eighth-block glyphs still need the 30-second zellij look (task 7.2).
