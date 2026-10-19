# Delta for pack-hint

## ADDED Requirements

### Requirement: Thin SessionStart hook

Toolkit hook `pack-hint.sh` MUST, on `startup`, run `timeout 1.5 ai-pack hint --cwd <hook input cwd>` (PATH, else `${XDG_BIN_HOME:-$HOME/.local/bin}/ai-pack`) and print its one line. hooks.json MUST set `"timeout": 2`, and the toolkit version MUST be bumped.

#### Scenario: Fallback binary
- GIVEN `ai-pack` is not on PATH but is in `~/.local/bin`
- WHEN the hook runs on `startup`
- THEN the hint line is printed

### Requirement: systemMessage only

The hook MUST emit the hint only as `systemMessage` and MUST NOT use `additionalContext`.

#### Scenario: Output shape
- GIVEN a hint is produced
- WHEN the hook output is parsed
- THEN it has `systemMessage` and no `additionalContext`

### Requirement: Silent failure and opt-out

The hook MUST stay silent when `ai-pack` is missing, times out, or fails, and when `AI_HOOKS_OFF=pack-hint`.

#### Scenario: Hooks off
- GIVEN `AI_HOOKS_OFF=pack-hint`
- WHEN the hook runs
- THEN there is no output

### Requirement: Hint detection and cadence

`ai-pack hint` MUST read `packs.json` from its own repo (via the realpath of `bin/ai-pack`) and, in the project, only root `package.json` and `index.html`. It MUST show a hint once per project and pack, again after 30 days, with a versioned output, suggesting `ai-pack add <pack>` and `ai-pack ignore <pack>`.

#### Scenario: Vite project
- GIVEN a root `package.json` depending on vite and no prior hint
- WHEN `ai-pack hint --cwd <dir>` runs
- THEN it prints one line suggesting `ai-pack add web`
- AND `hints.json` records the timestamp

#### Scenario: Cadence
- GIVEN the hint was shown 31 days ago, and separately 5 days ago
- WHEN `hint` runs
- THEN it prints in the first case and is silent in the second

### Requirement: Silence rules

`hint` MUST be silent when nothing is detected, the pack is ignored, or any tool of the pack is active (including a partly active pack). Any parse error MUST yield silence.

#### Scenario: Dotfiles repo
- GIVEN a project root with no `package.json` and no `index.html` (as in this repo)
- WHEN `hint` runs
- THEN nothing is detected and it is silent

#### Scenario: Partly active pack
- GIVEN only playwright of `web` is active in a vite project
- WHEN `hint` runs
- THEN it is silent

#### Scenario: Corrupt input
- GIVEN an unparseable `package.json`
- WHEN `hint` runs
- THEN it is silent

#### Scenario: Newer state schema
- GIVEN `hints.json` has a newer `schema_version`
- WHEN `hint` runs
- THEN it is silent and writes nothing

### Requirement: Write-limited and concurrency-safe

`hint` MUST write only `hints.json`, using `flock -n` (skip if busy) and temp file + `mv`.

#### Scenario: Concurrent sessions
- GIVEN two sessions start at once in the same vite project
- WHEN both run `hint`
- THEN at most one hint is shown
