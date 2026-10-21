# Look and feel

Two pieces: the `look` plugin (`plugins/look/`, a band above the prompt plus toasts) and the status line (`claude/statusline.sh`). Last verified with Claude Code 2.1.305.

## The band

A strip above the prompt. It is empty (nothing drawn) when nothing needs you. Rows, top to bottom:

| Row | Shows | Style |
|---|---|---|
| Alert | Failing CI of the branch PR, a backup problem, a failed agent | Pinned, red, with a `[n ✕]` button |
| Shell failure | A background shell that failed, with the time | Dim, no button |
| Activity | Running agents, background shells, pending CI | One joined line for 3 items or fewer, one row each above that |
| `+N more` | What did not fit in the band height | Last row |

Order is fixed: alerts, shell failures, activity. A joined activity line counts as its items for `+N more`. Text is cut with `…` to the pane width; every code point counts as one column.

Rules:

- Alerts stay until you dismiss them or their cause goes away (CI turns green, a new commit gives a new alert).
- Shell failures and finished items leave the activity line; a failed shell leaves one dim row.
- Running shells expire after 30 minutes. Agents have no expiry; an agent missing from the agent list on 2 consecutive polls (about 2 min) is finished as stopped, with a dim toast and no alert.
- Toasts announce each finish: a check mark for done, a cross for failed, dots for stopped. Toasts have no color in the API, so the glyph carries the tone. Finishes within 2 s of the first one merge into one count line (`2 done`).
- The band learns that a background task ended when Claude draws its notification in the chat, which happens on a turn. Claude delivers those one per turn, so two tasks ending together usually give two toasts, and in a quiet pane the end shows when the chat next moves. Dismissals and polls do not depend on this: they update an idle pane on their own.

## Glyphs (set A)

Needs a Nerd Font in the terminal; without one the glyphs show as boxes. All are private-use codepoints, one column wide.

| Meaning | Codepoint | Name |
|---|---|---|
| running | U+F0453 | nf-md-sync |
| agent | U+F06A9 | nf-md-robot |
| shell | U+F489 | nf-oct-terminal |
| CI | U+F407 | nf-oct-git_pull_request |
| backup | U+F0193 | nf-md-content_save |
| ok | U+F00C | nf-fa-check |
| fail | U+F00D | nf-fa-times |
| dim row | U+F01D8 | nf-md-dots_horizontal |

Source: `plugins/look/hooks/lib/glyphs.ts`. The alert row currently uses the fail glyph for all kinds.

## Keys

- `1` to `9` on an empty composer dismiss the alert with that number. The number is the 1-based position among alerts not yet dismissed; alerts past the ninth have no hotkey, only the button.
- Clicking `[n ✕]` does the same.
- `/band clear` dismisses every alert and clears running items and shell-failure rows. (The spec names only alerts and running items; shell-failure rows are included so the dim rows have a way out.)

## Shared across sessions

Everything else is per session. Two keys in `$.store` are shared:

| Key | Value | Purpose |
|---|---|---|
| `look:dismiss:<source>` | `{ at }` | A dismissal made in one pane hides the alert in the others. Entries older than 30 days or without a valid `at` are deleted. |
| `look:ci:<root>:<branch>` | gh result and fetch time | One `gh` call serves all sessions on the branch. `pr: 0` means no open PR. |

Alert sources: `ci:<root>:<branch>:<pr>:<sha>`, `backup:<rule>:<time>`, `agent:<id>`. A new commit or a new failure time is a new source, so it alerts again.

## Polling

| What | Cadence | Notes |
|---|---|---|
| CI | check every 60 s; `gh` runs only when the cache is stale: 60 s with pending checks or no open PR, 5 min otherwise | Also on a cwd change. `gh` timeout 10 s. Missing gh or an error keeps the last state for the same branch and logs under the `ci` tag (debug log) |
| Backup | 5 min | Reads the engram-backup state files, same rules as `plugins/toolkit/hooks/backup-status.sh`, plus `scan.json` |
| Agents | 60 s | Reconciles with `$.agent.list()` |
| Dismissals | 5 s | Reads the shared store |
| Elapsed time | 1 s | One tick only while something runs |

Timers start on `session.start`; the plugin has no `$` at load time.

## Status line

`claude/statusline.sh` prints one line, meters first so a narrow pane loses the end of the branch before any meter:

```
ctx ██▍░░░ 40% · 5h █▌░░░░ 25% · 7d ██████ 100% · Sonnet 4.6 · repo ⎇ branch*
```

- Meters: context, 5-hour quota, 7-day quota. Each is a 6-cell eighth-block bar with a dim track.
- Color by use: green below 50%, yellow below 80%, red from 80%.
- The 5-hour reset time (`↻HH:MM`) shows only from 80%.
- Then the model (without the `Claude ` prefix), the repo and branch. The branch is cut at 20 characters, the repo at 16. `*` marks a dirty tree. Outside a repo, only the directory name.
- Worst case is about 106 columns (a 4-character model name).

## Tests and the pin

- `bash plugins/look/tests/look.test.sh` runs `claude plugin validate` and `claude plugin test` (no auth, no network, isolated HOME). `make check` runs it.
- Without `claude` installed it prints SKIP and exits 0. `LOOK_REQUIRE_CLAUDE=1` turns that into a failure; CI sets it.
- `plugins/look/tests/claude-code.version` is the pinned Claude Code version (now 2.1.305). A different installed version prints a warning, not a failure. CI installs the pinned version.
- `bash scripts/tests/look-wrapper.test.sh` tests the wrapper itself (SKIP, require, version warning).
- `bash scripts/tests/statusline.test.sh` tests the status line.

Bump the pin:

1. Install the new version and run `bash plugins/look/tests/look.test.sh`; fix what broke in the mod API.
2. Write the version to `claude-code.version`.
3. Update "Last verified with Claude Code" at the top of this file.
4. Run `make check`.

## Where code and design differ

The code wins. Known differences from the design: agent state lives in `register/ingest.ts`, not `timers.ts`; there is no `session.cwd` event, so the CI root is re-resolved on every poll and the classic `CwdChanged` hook adds an extra one; the CI glyph is U+F407, not the running glyph.

## Manual checks

Not covered by automated tests; tick them after a real run (task 7.2). Record the result in the PR.

Checked on 2026-10-20 with Claude Code 2.1.305 in two zellij panes:

- [x] Status line in zellij: the eighth-block bars and dim track look right (30-second look).
- [x] Background shell: running line with elapsed time, then a done toast. A failing one leaves a dim row; the same command passing removes it.
- [x] Two panes: dismiss an alert in one; it disappears in the other within about 5 s, with the other pane idle.
- [ ] Atoms survive a hot reload of the plugin code, and no double tick appears afterwards.
- [x] Toasts: two tasks ending 0.5 s apart gave two toasts, because Claude delivers the notifications on separate turns (see the band rules). Not a defect.
- [x] `/band clear` clears the band (`/band` alone prints the usage).
- [ ] Real PR CI (a first try showed the 5 min "no PR" cache hid a new PR; it is 60 s now). Real PR with failing CI: the red alert appears, shows the failed check, and clears when CI passes.
- [x] Real backup state: a failed `backup.json` (temporary edit, restored) raised the alert in both panes, each within its own 5 min poll.
- [x] Digit hotkey in a real composer: `1` on an empty composer dismisses the first alert.
