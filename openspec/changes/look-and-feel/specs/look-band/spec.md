# Delta for Look Band

## ADDED Requirements

### Requirement: Idle and yielding

The band MUST draw nothing (`next(e)`) when there are no alerts, no shell-failure rows and nothing running. It MUST yield while `hasSurvey` is true. A collapsed band (ctrl+x ctrl+a) MUST keep alerts hidden until expanded.

#### Scenario: Idle

- GIVEN no alerts, rows or running items
- WHEN the band renders
- THEN nothing is drawn above the prompt

#### Scenario: Survey

- GIVEN a failing alert and `hasSurvey` true
- WHEN the band renders
- THEN it yields to the survey

### Requirement: Error fallback

Any render or poll error MUST fall back to `next(e)` and be logged once.

#### Scenario: Render error

- GIVEN a render that throws twice
- WHEN the band renders
- THEN `next(e)` is returned both times and one log entry exists

### Requirement: Render hook is read-only

The render hook MUST only read state; all transitions MUST be applied by a `$.clock.after(0, …)` dispatch. Displayed values MUST come from `$.state` atoms or be redrawn with `$.ui.invalidate`.

#### Scenario: Deferred write

- GIVEN a task-notification render for a known id
- WHEN the hook runs
- THEN no `$.state` write happens during the render
- AND the transition is applied after the zero-delay dispatch

### Requirement: Known-id ingestion

A Bash `tool.call` with `run_in_background` and an `agent.spawn` with `background` MUST add known running items. A task-notification MUST be ingested only for a known, unfinished id or `toolUseId`.

#### Scenario: Unknown id

- GIVEN a notification whose id was never seen starting
- WHEN it renders
- THEN no state changes

#### Scenario: Repeated or old notification

- GIVEN an item already finished
- WHEN its notification re-renders (reload, scroll, `--resume`)
- THEN it is ignored and no toast fires

### Requirement: Status mapping

Notification status MUST map `completed` to ok, `failed` to failed, `killed` to stopped, and any other value to stopped.

#### Scenario: Mapping

- GIVEN known items notified as `completed`, `failed`, `killed` and `weird`
- WHEN ingested
- THEN states are ok, failed, stopped and stopped

### Requirement: Shell failures

A failed background shell MUST raise one red toast and one dim row `⋯ <label> failed HH:MM`, keyed by the normalized command (leading `cd … &&` and `VAR=` prefixes stripped, first three words, `=value` masked). The next run of the same key MUST replace the row; a pass MUST remove it. The label MUST be the truncated Bash `description`, else the normalized command.

#### Scenario: Failure then pass

- GIVEN `make check` failed and left a dim row
- WHEN the same normalized command later completes ok
- THEN the row is removed

#### Scenario: Different commands

- GIVEN two failed commands sharing a first word but differing in words 2-3
- WHEN both fail
- THEN two separate rows exist

### Requirement: Stopped items

A `killed` shell or agent MUST show one dim "stopped" toast, with no alert and no row.

#### Scenario: Killed shell

- GIVEN a running known shell
- WHEN its notification reports `killed`
- THEN a dim toast appears and no alert or row remains

### Requirement: Shell expiry

A running shell with no notification MUST expire after 30 minutes. `/band clear` MUST clear running items.

#### Scenario: Expiry

- GIVEN a running shell with no notification
- WHEN 30 minutes pass
- THEN it is no longer shown as running

### Requirement: CI alerts

A failing check on the current branch's open PR MUST raise a red alert keyed by repo root + branch + PR + head SHA. The alert MUST be dropped when the branch changes, HEAD is detached, or the PR is no longer open, and MUST clear when CI next reports ok. The root MUST be re-resolved on `session.cwd` changes.

#### Scenario: Branch switch

- GIVEN a CI alert on branch A
- WHEN the branch changes to B
- THEN the alert is dropped

#### Scenario: Detached HEAD

- GIVEN `rev-parse --abbrev-ref HEAD` returns `HEAD`
- WHEN CI polls
- THEN no CI items exist

#### Scenario: Recovery

- GIVEN a CI alert
- WHEN the next poll reports all checks passing
- THEN the alert clears

### Requirement: CI normalization and absence

CheckRun (`status`/`conclusion`) and StatusContext (`state`) MUST be normalized. "no pull requests found" MUST mean no PR. Missing or unauthenticated `gh`, or a non-git directory, MUST yield no CI items and no noise. Pending checks on the PR MUST show as running activity.

#### Scenario: No PR

- GIVEN `gh` exits 1 with `no pull requests found for branch "b"`
- WHEN CI polls
- THEN no CI item or error is shown

#### Scenario: gh missing

- GIVEN `gh` is unavailable
- WHEN CI polls
- THEN no CI items appear and nothing is logged as a failure

### Requirement: CI polling and shared cache

Git/gh calls MUST run with cwd = repo root, a 10 s timeout and an in-flight guard (no overlap). A shared `$.store` cache `look:ci:<repo root>:<branch>` = `{ at, pr, headSha, checks }` MUST be polled by the session that finds it older than 60 s (pending checks) or 5 min (otherwise); other sessions MUST read it.

#### Scenario: Fresh cache

- GIVEN a cache entry younger than its interval
- WHEN a session ticks
- THEN it reads the cache and runs no process

#### Scenario: Stale cache

- GIVEN a cache entry older than its interval
- WHEN a session ticks
- THEN it polls and rewrites the entry

### Requirement: Backup alert

The band MUST raise a backup alert under the `backup-status` rules (last backup or verify failed, backup older than 2 days, verify older than 8, none recorded when `${XDG_CONFIG_HOME:-$HOME/.config}/restic/engram.env` exists) plus a failed or blocked secret scan in `scan.json`, reading from `${XDG_STATE_HOME:-$HOME/.local/state}/engram-backup/`. It MUST poll every 5 min, clear when the source reports ok, and raise nothing when backup is not configured.

#### Scenario: Stale backup

- GIVEN `backup.json` older than 2 days
- WHEN the backup poll runs
- THEN a red backup alert appears

#### Scenario: Blocked scan

- GIVEN `scan.json` reports blocked
- WHEN the poll runs
- THEN a backup alert appears

#### Scenario: Not configured

- GIVEN no `engram.env` and no state files
- WHEN the poll runs
- THEN no alert appears

### Requirement: Agent alerts

A background agent ending `failed` MUST raise a red alert that clears only when dismissed and MUST NOT be restored after a resume. `$.agent.list()` MUST be polled every 60 s as a fallback.

#### Scenario: Failed agent

- GIVEN a known background agent
- WHEN its notification reports `failed`
- THEN a red alert persists until dismissed

#### Scenario: Resume

- GIVEN a session resumed after an agent failure
- WHEN the old notification re-renders
- THEN no alert is created

#### Scenario: Agent vanished from the list

- GIVEN a known running agent that `$.agent.list()` does not list on 2 consecutive polls
- WHEN the second poll runs
- THEN it is removed with a dim "stopped" toast and no alert; listing it again resets the count

### Requirement: Activity layout

Running shells, agents and pending CI checks MUST show on one line when 3 or fewer, and one row each when more than 3. Rows MUST NOT exceed `maxRows`; extra items MUST fold into `+N more`. Nothing is right-aligned, elapsed time follows the label, two columns of `bodyColumns` are reserved, and labels are truncated, never wrapped. Glyphs are the plan's Nerd Font set A.

#### Scenario: Three items

- GIVEN 3 running items
- WHEN the band renders
- THEN one activity line is drawn

#### Scenario: Overflow

- GIVEN 6 running items and `maxRows` allowing 4 rows
- WHEN the band renders
- THEN rows are capped and the remainder shows as `+N more`

### Requirement: Dismissal

Each alert row MUST have a `✕` Button with hotkey `1`…`9`. `/band clear` MUST dismiss all alerts. Dismissals MUST be `$.store` keys `look:dismiss:<source key>` (CI head SHA, backup time + rule, agent id), shared by sessions, re-read every 5 s, and pruned after 30 days. A new failing event (new head SHA, backup time or agent) MUST re-raise.

#### Scenario: Hotkey

- GIVEN two alerts and an empty composer
- WHEN `1` is pressed
- THEN the first alert is dismissed and its store key is written

#### Scenario: Cross-session

- GIVEN a dismissal key written by another session
- WHEN the 5 s tick runs
- THEN the alert clears here

#### Scenario: Re-raise and prune

- GIVEN a dismissed CI alert and a new head SHA failing
- WHEN CI polls
- THEN a new alert appears
- AND dismissal keys older than 30 days are deleted

### Requirement: Toasts

A green toast MUST show once per running to ok transition, a red toast once per failed shell, and a dim toast once per stopped item. Toasts within 2 s MUST merge.

#### Scenario: Merge

- GIVEN two items finish within 2 s
- WHEN toasts fire
- THEN one merged toast is shown

### Requirement: Timers

Timers MUST start from `session.start` and at module load behind an idempotent guard. A 1 s UI tick MUST run only while items run; a 5 s tick re-reads dismissals. Every callback MUST be wrapped in try/catch.

#### Scenario: Hot reload

- GIVEN a reload re-running `register` and `session.start`
- WHEN the new instance starts
- THEN only one set of timers is active and the old one stopped

#### Scenario: Idle tick

- GIVEN nothing is running
- WHEN time passes
- THEN no 1 s UI tick fires

### Requirement: Mod tests in CI

Mod tests MUST run via `claude plugin test` in the check job on pinned Claude Code 2.1.305, and locally through `plugins/look/tests/look.test.sh`, which MUST SKIP with a message when `claude` is missing and print `claude --version`, warning when it differs from the pin.

#### Scenario: No claude

- GIVEN `claude` is not installed
- WHEN the wrapper runs
- THEN it prints a SKIP message and exits successfully

#### Scenario: Version mismatch

- GIVEN `claude --version` differs from 2.1.305
- WHEN the wrapper runs
- THEN the version is printed with a warning and tests still run
