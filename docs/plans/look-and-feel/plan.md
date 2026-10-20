# Plan: Claude Code look and feel

- Status: approved (reviews 1 and 2 resolved; spikes 1 and 2 done; remaining detail goes to TDD)
- Deadline: none
- Mode: solo
- Supersedes: none (roadmap item "Claude Code look and feel: theme, visual tweaks and TUI mods")

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Claude Code CLI in kitty + zellij on Arch | yes | Claude Code 2.1.305 pinned in CI (spikes ran on the session's 2.1.304; the mod API is version-sensitive); terminal ~70+ columns, zellij splits | this repo's marketplace (new plugin `look`) + `claude/statusline.sh` |
| Claude desktop / VS Code / mobile surfaces | no | - | - |

- Out of scope: other terminals, the desktop app, themes beyond `dark-ansi`.

## Research

Mod API of the session's build (`plugin-authoring` types and reference, regenerated in `/tmp/claude-1000/bundled-skills/<version>/` each time the skill loads; they vanish when Claude Code updates):

- Background Bash: `tool.call` result carries `result.backgroundTaskId`; the end is a `UserMessage` render with `origin.kind == 'task-notification'` and `props.task = { id, status, toolUseId }`.
- `$.state` writes are refused while a `ui.render` hook draws (types: "Refused while a `ui.render` hook draws (write from `onPress` or another event)"): the render hook only reads and defers writes with `$.clock.after(0, …)`.
- `AbovePrompt` props: `isWorking`, `hasSurvey`, `maxRows` (half the terminal), `bodyColumns`; `next(e)` draws nothing; redraws only on `$.state` atom changes, `$.ui.invalidate`, width/focus changes.
- Band `Button`s take a `hotkey` (one digit or lowercase letter): pressed after ctrl+x tab, a click, or a bare digit typed into an empty composer.
- `$.clock.every`/`after`, `$.process.run(argv, { timeoutMs })` (no shell), `$.fs.read`/`write`/`exists`, `$.env.get`, `$.store.get/set/delete/keys` (JSON under `~/.claude/plugins/store/<plugin>…json`, 4 MiB), `$.ui.toast`, `$.command.register`.
- Tests: `claude plugin test` (`claude-code/testing`: `mock.clock`, `mock.store`, `mock.env`, `mock.session`, `$.ui.mount`); process, fs and agent calls are stood in by the test's own hooks (`on('process.run', …)`, `on('fs.read', …)`, `on('agent.list', …)`). `claude plugin test` and `validate` run with an empty HOME and no account (verified locally and in `archlinux:latest` with `npm install -g @anthropic-ai/claude-code@2.1.305` + `node "$(npm root -g)/@anthropic-ai/claude-code/install.cjs"`, ~13 s).

### Spike results (probe mods, kitty + zellij, 2026-10-20)

- Background Bash ends: `status: 'completed'` for exit 0, `'failed'` for a non-zero exit (`false`).
- Agents: `agent.spawn` fires for the model's Agent tool calls (`background: true`, `description`, `model`, `tool_use_id`); their end is the same task-notification (`{ id: <agentId>, status, toolUseId, durationMs }`); `$.agent.list()` shows them `completed`.
- `gh`/`git` through `$.process.run` work (gh authenticated; no PR = exit 1, stderr `no pull requests found for branch "<b>"`); `$.env.get('XDG_STATE_HOME')` works.
- Hot reload: `register` and `session.start` run again in a new module instance; the old timer stops.
- Old task-notification rows re-render (after a reload, and an earlier agent's row reappeared later in the session).
- `$.store` is shared between two live sessions (each read the other's key within one 10 s poll).
- A band Button with `hotkey: "1"` was pressed by typing `1` into an empty composer, in both sessions.
- A count kept in a module variable showed stale values in the band until a redraw: displayed values live in `$.state` atoms or go through `$.ui.invalidate`.
- Nerd Font glyphs (set A below) and emoji render aligned in kitty + zellij (AtkynsonMono Nerd Font).

## Product vision

- **v1:** a calm screen: the bottom status line shows the meters first (context, 5h and 7d as precise bars) and then the place (model, repo, branch with a dirty marker); a band above the prompt appears only while something runs or failed: CI, backup and agent failures pinned in red until they recover or are dismissed, shell failures as a red toast plus a dim row, finished work as a short toast.
- **v2:** more sources (PR review state, engram save failures, upstream-watch news), a `/band` history, theme tweaks.

## Core model

```
item      id (toolUseId / task id / agent id / "ci:<repo>:<branch>:<pr>" / "backup"), kind: ci | agent |
          shell | backup, label, startedAt, state: running | ok | failed | stopped
known     ids this session saw start (tool.call Bash background, agent.spawn background); a
          task-notification is ingested only if its id/toolUseId is known and not finished
alert     a failed ci | agent | backup item; clears when its source recovers (ci, backup) or when
          dismissed; agent alerts clear only when dismissed and are not restored after a resume
shellfail a failed shell: red toast once + one dim row keyed by the normalized command, replaced
          by the next run of the same command (a pass removes it)
stopped   `killed` shells/agents: a dim "stopped" toast, no alert, no row
dismissal $.store key `look:dismiss:<source key>` (CI head SHA, backup time + rule, agent id), one key
          per dismissal; read by every session on a 5 s tick; keys older than 30 days pruned
ci cache  $.store key `look:ci:<repo root>:<branch>` = { at, pr, headSha, checks }; the session whose
          read finds it older than the interval polls and writes it, the others read it
band      derived from atoms: alerts (red) + shellfail rows (dim) + running items (one line; one row
          each when > 3; "+N more" past maxRows)
toast     once per running -> ok (green) / failed shell (red) / stopped (dim); toasts within 2 s merge

events: tool.call (Bash background), agent.spawn (background), task-notification render (read
        only; ingestion deferred with $.clock.after(0)), CI poll, backup poll, session.start +
        module load (idempotent timers), session.cwd change, /band clear, Button press / hotkey
```

## Foundation

n/a: existing repo conventions (bash for the status line; the band is a TypeScript mod in `plugins/look/`; mod tests with `claude plugin test`; conventional commits; strict TDD).

## Screens

### Status line (bottom)

```
ctx ██▌    42% · 5h █████  84% ↻14:00 · 7d ███▋   61% · Opus · DOTFILES IA ⎇ main*
```

- Chosen: review-1 B with C's bars and bar style B; review-1 Q1: dirty `*`, 5h reset only at >= 80%, no zellij name; review-2 Q3: meters first, place last.
- Rules: order `ctx · 5h [↻HH:MM] · 7d · model · repo ⎇ branch[*]`; bars of 6 cells with 1/8-cell precision (`█▉▊▋▌▍▎▏`, 48 steps) and a dim track for empty cells; color per meter green < 50%, yellow < 80%, red otherwise; model name without a leading "Claude "; repo <= 16 and branch <= 20 chars with `…`. Claude Code gives the script no width and truncates on the right, so narrow panes lose the end of the branch, never a meter. Worst case ~100 columns, typical ~75.
- States: no git -> no branch; no `rate_limits` -> only ctx; a missing quota omits that meter; 0% -> a dim track.
- Changes to existing behaviour (tests and README rows updated): zellij name removed; 5h reset only at >= 80%; order changed; 7d meter new. A test asserts the order (meters before the place) and the worst-case visible length; the eighth-block glyphs get a 30-second visual check in zellij.

| UI element | Backend demand |
|---|---|
| 7d meter | `rate_limits.seven_day.used_percentage` |
| reset at >= 80% | `rate_limits.five_hour.resets_at` (epoch) |
| bars | integer math on percent -> 48 steps -> full cells + one partial glyph + dim track |

### Band above the prompt

```
✖ CI #17 · check failed  [1 ✕]
✖ agent "npm implementation" failed  [2 ✕]
⋯ make check failed 12:03
⏳ CI #18 1m20s · 🤖 2 agents · ⚙ make check 38s
> _
```

(Emoji above only for readability; the band draws the Nerd Font glyphs listed under Rules.) More than 3 running items become one row each, nothing right-aligned:

```
⏳ CI #18 check running · 1m20s
🤖 PR 3 validator · 4m02s
🤖 npm implementation · 11m40s
⚙ make check (background) · 38s
```

- Chosen: review-1 C with B's rows; review-1 Q2 (shell failures toast + dim row), Q3 (shared dismissals), Q4 (backup rules mirror backup-status); review-2 Q2 (`killed` neutral), Q4 (resume).
- Rules:
  - Draw nothing when there are no alerts, no shellfail rows and nothing runs (`next(e)`). Yield while `hasSurvey`. Any render or poll error falls back to `next(e)` and is logged once. Everything drawn is read from `$.state` atoms (or redrawn with `$.ui.invalidate`).
  - Ingestion: `tool.call` (Bash, `run_in_background`) and `agent.spawn` (`background`) add known running items. The `UserMessage` render hook only reads `props.task` and returns `next(e)`; a `$.clock.after(0, …)` dispatch applies the transition, only for a known, unfinished id/`toolUseId`. Re-rendered or older notifications (reloads, scrolls, `--resume`) are ignored. Status: `completed` -> ok, `failed` -> failed, `killed` -> stopped, anything else -> stopped.
  - Alerts (pinned, red): a failing CI check on the current branch's open PR; backup per the `backup-status` rules (last backup or verify failed, backup older than 2 days, verify older than 8, none recorded when `${XDG_CONFIG_HOME:-$HOME/.config}/restic/engram.env` exists) plus a failed or blocked secret scan (`scan.json`), from `${XDG_STATE_HOME:-$HOME/.local/state}/engram-backup/`; a background agent ending `failed`. CI alerts are keyed by repo root + branch + PR + head SHA and are dropped when the branch changes, HEAD is detached, or the PR is no longer open; CI and backup alerts clear when their source next reports ok; agent alerts clear only when dismissed.
  - Dismissal: each alert row has a Button `✕` with `hotkey` `1`…`9` (a bare digit in an empty composer presses it; also ctrl+x tab then the digit); `/band clear` dismisses all. Dismissals are `$.store` keys `look:dismiss:<source key>` shared by every session (re-read on a 5 s tick); a new failing event (new head SHA, new backup time, new agent) re-raises; keys older than 30 days are pruned.
  - Shell failures: a red toast once and one dim row `⋯ <label> failed HH:MM` keyed by the normalized command (leading `cd … &&` and `VAR=` prefixes stripped, first three words, `=value` masked), replaced by the next run of the same command (a pass removes it). Labels show the Bash `description` (truncated), else the normalized command.
  - Activity: background shells (until the notification; expire after 30 min without one), background agents (until the notification; `$.agent.list()` every 60 s as a fallback), pending CI checks on the current branch's PR. One line when <= 3 items, one row each when > 3; rows never exceed `maxRows`, extra items fold into `+N more`.
  - Layout: nothing right-aligned; elapsed time follows the label; two columns of `bodyColumns` reserved; labels truncated, never wrapped.
  - Glyphs (Nerd Font set A, verified aligned): running U+F0453 (nf-md-sync), agent U+F06A9 (nf-md-robot), shell U+F489 (nf-oct-terminal), CI/PR U+F407 (nf-oct-git_pull_request), backup U+F0193 (nf-md-content_save), ok U+F00C (nf-fa-check), fail U+F00D (nf-fa-times), dim row U+F01D8 (nf-md-dots_horizontal).
  - Toasts: green once per running -> ok, red once per failed shell, dim once per stopped item; toasts within 2 s merge.
  - Timers: started from `session.start` and at module load behind an idempotent guard (a hot reload runs both again in a new instance); a 1 s UI tick only while items run; a 5 s tick re-reads dismissals; every timer callback is wrapped in try/catch (a refused period ends an interval); polls never overlap and use a 10 s timeout.
  - CI polling: `git -C <root> rev-parse --abbrev-ref HEAD` (detached `HEAD` -> no CI), then `gh pr view <branch> --json number,state,headRefOid,statusCheckRollup` with cwd = root; "no pull requests found" = no PR; CheckRun (`status`/`conclusion`) and StatusContext (`state`) normalized. The root is re-resolved on `session.cwd` changes. Shared cache per repo + branch: 60 s while the PR has pending checks, 5 min otherwise.
  - Backup polling: every 5 min.
  - A collapsed band (ctrl+x ctrl+a) is the user's choice: alerts stay hidden until expanded.
- States: idle -> nothing; gh missing or unauthenticated -> no CI items, no noise; backup not configured -> no backup alert; not a git repo -> no CI.

| UI element | Backend demand |
|---|---|
| CI items/alerts | `$.process.run` of git/gh with cwd = repo root; normalized rollup; `$.store` cache per repo + branch |
| shell items/rows | `tool.call` hook: `backgroundTaskId`, description, normalized command; deferred notification ingestion; 30 min expiry |
| agent items/alerts | `agent.spawn` hook + deferred notification ingestion + 60 s `$.agent.list()` fallback |
| backup alert | `$.fs.read` of `backup.json`, `verify.json`, `scan.json`; `$.fs.exists` of `engram.env`; the backup-status rules |
| ✕ / clear | Buttons with digit hotkeys + `/band clear`; `$.store` dismissal keys |
| toasts | `$.ui.toast` on transitions, 2 s merge window |

## Data captured / data inventory

| Screen | Data shown | Actions (events) | Source |
|---|---|---|---|
| Status line | ctx %, 5h % (+ reset at >= 80%), 7d %, model, repo, branch + dirty | none | status line JSON + git |
| Band | alerts, shell failure rows, running items, elapsed time | ✕ (digit hotkeys or click), /band clear | tool.call, agent.spawn, task notifications, gh, engram-backup state files |
| Toast | finished, failed or stopped item | click dismiss | transitions in band state |

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| Regenerate the mod types for the build in use (load the plugin-authoring skill) before writing the mod | MUST (first) | 0.1 | high |
| Status line redesign (meters first, 7d, eighth-block bars, dim track, dirty `*`, reset at >= 80%, length budgets) + rewritten tests (order, worst-case length) + README rows | MUST | 0.75 | high |
| Plugin `look` scaffold: `plugins/look/.claude-plugin/plugin.json`, `hooks/hooks.json`, `hooks/register.tsx`, `types/index.d.ts` (state contract), `.claude-plugin/marketplace.json` entry, `install.sh` `PLUGINS` += look, README plugin row, `check-structure.sh` passes | MUST | 0.5 | medium |
| Band: background shells (known-id ingestion, deferred writes, expiry, description/normalized labels, red toast + dim row, stopped toast) | MUST | 0.85 | high |
| Band: background agents (spawn, notification, 60 s fallback, alerts, no restore after resume) | MUST | 0.75 | high |
| Band: CI (git/gh, normalization, branch/PR/SHA keys, detached HEAD, cwd changes, shared per-repo cache, in-flight guard) | MUST | 1.0 | high |
| Band: backup alert (backup-status rules + scan.json, XDG paths) | MUST | 0.5 | medium |
| Band layout (atoms, line/rows/`+N more`/`bodyColumns`, UI tick, digit-hotkey ✕, `/band clear`, toast merge, error fallback) | MUST | 0.75 | high |
| Shared dismissals (per-key `$.store` entries, 5 s re-read, pruning) | MUST | 0.25 | high |
| Mod tests (`claude plugin test`; process/fs/agent stood in by test hooks; resume and reload cases) + `plugins/look/tests/look.test.sh` wrapper (runs them; SKIP with a message when `claude` is missing; prints `claude --version` and warns when it differs from the CI pin) | MUST | 1.0 | medium |
| CI: `nodejs npm` added to the check job's pacman list, Claude Code 2.1.305 installed (npm + `install.cjs`), validate + test run; upstream-watch entry for `anthropics/claude-code` releases (checked to exist) to bump the pin | MUST | 0.25 | medium |
| docs/look.md (what the band shows, rules, keys, the version last verified) + README rows | MUST | 0.25 | low |
| Manual two-pane check (dismissal in one pane clears the other) and a 30-second zellij look at the status line bars | MUST | 0.1 | high |
| Theme tweaks beyond `dark-ansi` | LATER | - | low |
| v2 sources (PR review state, engram save failures, upstream news), `/band` history | LATER | - | medium |

Total MUST: ~7.1 dev-days; no deadline, solo -> fits.

## Demo data

Mod tests drive events directly: a background Bash `tool.call` + notifications (`completed`, `failed`, `killed`, an unknown id, a repeated one), an agent spawn + notification, mocked `gh` output (pending, failed, passed, "no pull requests found", detached HEAD), backup state files for each rule, a store pre-filled with a dismissal. Manual demo: `sleep 30` and `false` in the background, a background agent, a branch with a PR, two zellij panes.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| Band next to the `statusLine` command | Drawn together (spike 1) | Claude | yes |
| Task-notification shape and statuses | `{ id, status, toolUseId }`; `completed` / `failed` seen (spikes) | Claude | yes |
| Agents visible to the mod | `agent.spawn` + the same notification (spike 1) | Claude | yes |
| `gh` auth inside `$.process.run` | Works (spike 1) | Claude | yes |
| Glyph widths in kitty + zellij | Nerd Font set A aligned (spike 1, user check) | user | yes |
| `$.store` shared across sessions | Yes (spike 2, two live sessions) | Claude | yes |
| Keyboard path for ✕ | Digit hotkey in an empty composer (spike 2) | Claude | yes |
| API on 2.1.305 vs the session's 2.1.304 | Same shapes; CI runs the mod tests on the pinned 2.1.305 | Claude | no |
| Eighth-block bars in zellij | Render cleanly; 30-second check during the status line task | user | no |

## Deferred to v2

- Theme tweaks — `dark-ansi` already follows kitty's palette.
- More band sources and a `/band` history — after v1 proves useful.

## Demo priorities

1. Idle session: nothing above the prompt; the status line shows ctx, 5h and 7d bars first, then the place with the dirty marker.
2. A background `make check` and a background agent appear in one line; a pass shows a toast and disappears; a failing `make check` leaves a dim row that the next green run removes; a stopped agent leaves only a dim toast.
3. A failing CI check pins a red alert in every pane; `1` in an empty prompt dismisses it everywhere; the next passing run or a branch switch clears it on its own.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: the band's `$.state` types contract and the `$.store` key layout (`look:dismiss:*`, `look:ci:*`)
- Work packages: n/a

## Plan-review resolutions

Source: `plan-review-1.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Status line silently drops features | Keep dirty `*`; 5h reset only at >= 80%; drop the zellij name; tests and README rows named | user (Q1) |
| 2 | Width claim wrong | Superseded by review-2 #7: meters first, worst case ~100 stated, order + length tested | user (review-2 Q3) |
| 3 | Timers stop after hot reload | Spike: a reload re-runs `register` and `session.start`; idempotent guard kept | planner |
| 4 | Shell items stuck without a notification | 30 min expiry; `/band clear` clears running items | planner |
| 5 | CI alerts stuck after branch switch / PR closed | Keyed by repo + branch + PR + head SHA; dropped on branch change, detached HEAD or PR not open | planner |
| 6 | Dismiss semantics undefined | Keyed by source event; re-raised only by a new event; per-key `$.store` entries shared by sessions | planner + user (Q3) |
| 7 | Agent source inconsistent/unverified | `agent.spawn` + task-notification (spike); 60 s `$.agent.list()` fallback | planner |
| 8 | Emoji widths wrong | Nerd Font set A verified aligned; nothing right-aligned; 2 columns reserved | user + planner |
| 9 | Elapsed times freeze | 1 s UI tick only while items run | planner |
| 10 | Backup alert duplicates backup-status with other rules | Same rules + scan.json, XDG paths; hook stays as fallback; backup stays MUST | user (Q4) |
| 11 | Rollup shapes and no-PR exit | Normalize CheckRun/StatusContext; "no pull requests found" = no PR | planner |
| 12 | cwd, timeouts, overlapping polls | cwd = repo root, 10 s timeout, in-flight guard | planner |
| 13 | Mod tests never run in CI | Claude Code 2.1.305 pinned in the check job (verified without an account); `.test.sh` wrapper | user (Q5) |
| 14 | Install wiring under-specified | Scaffold row names every file | planner |
| 15 | `$.ui.status` check without a use | Dropped | planner |
| 16 | Raw command labels, toast bursts | Superseded by review-2 #8; toasts within 2 s merge | planner |
| 17 | Model name and empty bars | Strip a leading "Claude "; dim track for empty cells | planner |
| Q2 | Shell failures during TDD | Red toast + dim row, replaced by the next run; only CI, backup and agents pin | user |

Source: `plan-review-2.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | `$.state` writes refused inside `ui.render` | Render hook only reads; transitions applied by a `$.clock.after(0)` dispatch; mod test asserts it | planner |
| 2 | Dedupe lost on resume | Only notifications for ids this session saw start are ingested; resume test | planner + user (Q4) |
| 3 | Failing shell status unverified | Spike 2: `false` -> `status: 'failed'` | planner |
| 4 | Cross-session `$.store` unverified, no CAS | Spike 2: shared; per-key dismissal entries (no shared map), 5 s re-read, 30-day pruning; manual two-pane check | planner |
| 5 | CI cache not keyed | `look:ci:<repo root>:<branch>` | planner |
| 6 | ✕ needs a keyboard path | Digit hotkeys (verified in spike 2), ctrl+x tab, `/band clear` | planner (Q1 answered by the spike) |
| 7 | Status line worst case ~105 columns | Meters first, place last; worst case ~100 stated; order and length tested | user (Q3) |
| 8 | First-word labels collide | Row key = normalized command (prefixes stripped, first three words, masked); label = description | planner |
| 9 | Reload wording contradictory | One wording: a reload re-runs `register` and `session.start`; idempotent guard | planner |
| 10 | Resolutions table drift | Tables rewritten to match the rules | planner |
| 11 | CI needs nodejs/npm; version drift; upstream-watch | `nodejs npm` in pacman; wrapper warns on version mismatch; upstream-watch on `anthropics/claude-code` releases (checked) | planner |
| 12 | `killed` treated as failed | Neutral: dim "stopped" toast, no alert | user (Q2) |
| 13 | Undefined states | Detached HEAD -> no CI; root re-resolved on cwd change; collapse is user intent; engram.env path in full; stale backup key = time + rule | planner |
| 14 | Test kit limits | Process/fs/agent stood in by test hooks; cross-session behaviour covered by the manual two-pane check | planner |
| risks | Re-renders, version drift, Stop-hook time, timer errors, bar glyphs | Known-id ingestion; pin + warning + upstream-watch + "last verified" in docs; keep mod tests fast and measure them in require-check; try/catch in every timer; 30-second zellij check | planner |
