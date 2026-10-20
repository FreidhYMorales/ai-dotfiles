# Delta for ai-pack-cli

## ADDED Requirements

### Requirement: Commands and project key

`ai-pack` MUST provide `list`, `add <pack|tool>`, `remove <pack|tool> [--purge]`, `ignore <pack>`, `unignore <pack>`, and internal `hint --cwd <dir>`. The project key MUST be the git root realpath of the cwd, else the realpath of the cwd, from one function.

#### Scenario: Subdirectory and non-git
- GIVEN a subdirectory of a git repo, and separately a non-git directory
- WHEN `ai-pack add archify` runs in each
- THEN the first resolves to the repo root and the second uses the cwd as the project

### Requirement: Startup dependency check

At startup `ai-pack` MUST check `jq`, `flock`, `curl`, `sha256sum` and print the exact pacman line for a missing one. Kind `npm` MUST require `npm` (`sudo pacman -S npm`).

#### Scenario: Missing jq
- GIVEN `jq` is absent
- WHEN any command runs
- THEN it prints the pacman install line and writes nothing

### Requirement: Preflight before any write

`add` MUST validate the whole pack first (requirements with min versions, downloads, checksums, integrity). On any preflight failure nothing MUST be written.

#### Scenario: Missing chromium
- GIVEN chromium is absent
- WHEN `ai-pack add web` runs
- THEN it prints "chromium not found; install it with: sudo pacman -S chromium" and "nothing was written"

#### Scenario: Integrity or network failure
- GIVEN a checksum mismatch, or a network error during preflight
- WHEN `add` runs
- THEN it aborts and writes nothing

### Requirement: Self-ignoring whole-dir project writes

Project writes MUST be whole dirs only (`.claude/skills/<tool>/`, `.playwright/`), each containing `.gitignore` with `*`. `ai-pack` MUST NOT edit existing files, `settings.local.json`, or `info/exclude`. Each dir MUST be built in `<project>/.claude/.ai-pack-stage-<id>/` and moved with `mv -T` (new) or `mv -T --exchange` (replace).

#### Scenario: Worktrees stay clean
- GIVEN a repo with two worktrees
- WHEN `ai-pack add web` runs in one
- THEN `git status` is clean in both
- AND no pack file appears in other projects

#### Scenario: Re-sync without nesting
- GIVEN an active tool whose manifest version changed
- WHEN `add <tool>` runs
- THEN the dir is replaced with no nested copy

### Requirement: Journal after move

The per-file journal (path + sha256) in `projects.json` MUST be written after the move, under the lock. Stale stages MUST be deleted under the lock at the start of every `add` and `remove`.

#### Scenario: Killed run
- GIVEN a run killed after a move and before journaling, leaving a stale stage
- WHEN the next `add` runs
- THEN the stale stage is deleted

### Requirement: Adoption by hash

A dir with no journal entry whose pinned hash matches MUST be shown as "adoptable" by `list` (read-only) and adopted by the next `add`, including at a moved project path. Any other existing target MUST be refused with nothing written.

#### Scenario: Adoptable then adopted
- GIVEN an unjournaled dir matching the pinned hash
- WHEN `list` runs, then `add`
- THEN `list` shows "adoptable" and writes no state, and `add` journals it

#### Scenario: Foreign target
- GIVEN an existing target dir whose hash differs and has no journal
- WHEN `add` runs
- THEN it refuses and writes nothing

### Requirement: Rollback after preflight

A failure after preflight MUST roll back the dirs moved and npm prefixes staged in this run.

#### Scenario: Second tool fails
- GIVEN the first tool of a pack was moved into place
- WHEN a later tool fails
- THEN the first tool's dir is removed and no journal entry remains

### Requirement: State files and locking

State in `~/.local/state/ai-pack/` MUST be `machine.json`, `projects.json`, `ignored.json`, `hints.json` with `schema_version` 1, written via temp file + `mv` under `flock` on `./lock`. A newer `schema_version` MUST refuse writes (and `hint` stays silent); an older one MUST use defaults for missing keys.

#### Scenario: Newer schema
- GIVEN `projects.json` with a newer `schema_version`
- WHEN `add` runs
- THEN it refuses and writes nothing

#### Scenario: Older schema
- GIVEN an older file missing keys
- WHEN `list` runs
- THEN defaults are used and it succeeds

### Requirement: npm machine layer

Each npm version MUST install into `~/.local/share/ai-pack/npm/<tool>@<ver>.staging` via the `npm pack` tarball (sha512 checked) with `--ignore-scripts`, then `mv -T` to `<tool>@<ver>`, then the `~/.local/bin` link is switched atomically. `machine.json` is recorded only after that; old prefixes stay until `--purge`. A bin link MUST be refused if `~/.local/bin/<bin>` exists and was not created by ai-pack.

#### Scenario: Network failure during install
- GIVEN preflight passed and npm fails mid-install
- WHEN `add` runs
- THEN the staging prefix is removed and `machine.json` is unchanged

#### Scenario: Bin collision
- GIVEN a foreign file at `~/.local/bin/playwright-cli`
- WHEN `add web` runs
- THEN it refuses and writes nothing

### Requirement: Refcounts and shared tools

A shared tool MUST deactivate in a project only when no active pack there needs it. Machine installs MUST stay after the last project removes them. `list` shows "(via web)" from the per-project refcount.

#### Scenario: Shared tool kept
- GIVEN two active packs needing one tool
- WHEN one pack is removed
- THEN the tool stays active

### Requirement: Remove behavior

`remove` MUST delete journaled files whose sha256 still matches, then the dir if empty apart from `.gitignore` and declared leftovers, and print leftovers (e.g. `.playwright/output/`) without deleting them. It MUST tolerate dirs removed by hand.

#### Scenario: Hand-edited file
- GIVEN a journaled file edited by hand
- WHEN `remove` runs
- THEN it warns, keeps the dir, drops the journal entry (refcount drops)
- AND prints "delete <path> to re-add"

#### Scenario: Runtime output
- GIVEN `.playwright/output/` has files
- WHEN `remove web` runs
- THEN other files are removed, the leftover is printed and kept

### Requirement: Re-sync over hand edits

`add` on an active tool MUST re-sync to the manifest version, but when the tree hash differs it MUST warn and not overwrite.

#### Scenario: Edited copy
- GIVEN a hand-edited installed copy
- WHEN `add <tool>` runs
- THEN it warns and the copy is unchanged

### Requirement: Purge rules

`remove --purge` MUST uninstall only when no existing project uses the tool. Entries whose project root no longer exists MUST be shown and dropped under the lock. If any existing project uses it, it MUST refuse, list those projects, and offer no override.

#### Scenario: Live projects
- GIVEN playwright used by two existing projects
- WHEN `remove --purge playwright` runs
- THEN "error: still used by <paths>; nothing removed"

#### Scenario: Dead roots
- GIVEN the only users have deleted roots
- WHEN `remove --purge` runs
- THEN dead entries are shown and dropped and the tool is uninstalled

### Requirement: List output

`list` MUST show packs and tools with active state from `projects.json` plus real presence, "(via pack)", machine version vs journal version, drift ("3.2.0 -> 3.3.0 available"), "shadowed by", lines within 70 columns. It MUST skip projects whose root is gone without writing state.

#### Scenario: Drift and width
- GIVEN archify journaled 3.2.0 and manifest 3.3.0
- WHEN `list` runs
- THEN it shows the drift and no line exceeds 70 columns

### Requirement: Shadow warning

`add` and `list` MUST warn when a personal or plugin skill shadows the project copy by directory name or frontmatter `name`, scanning `~/.claude/skills` and the plugin cache recursively to maxdepth 4.

#### Scenario: Nested shadow
- GIVEN `~/.claude/skills/synced/<id>/design-taste-frontend`
- WHEN `list` runs
- THEN taste shows "shadowed by" that path

### Requirement: Machine-wide upgrade

A manifest bump of a machine tool applied from one project MUST upgrade it for every project; `list` shows the version everywhere and `add` prints "restart your Claude sessions".

#### Scenario: Upgrade notice
- GIVEN playwright 0.1.22 is installed and the manifest says 0.1.23
- WHEN `add playwright` runs in project A
- THEN project B's `list` shows machine 0.1.23

### Requirement: Ignore and unignore

`ignore <pack>` and `unignore <pack>` MUST record and clear the pack in `ignored.json` for the project key.

#### Scenario: Ignore round trip
- GIVEN `web` is ignored
- WHEN `unignore web` runs
- THEN `ignored.json` no longer lists it

### Requirement: Post-change notices

After changes `ai-pack` MUST print "run /reload-plugins" (skills only) or "restart Claude in this project" (Playwright config).

#### Scenario: Skill-only add
- GIVEN `add archify` succeeds
- WHEN output is read
- THEN it ends with "run /reload-plugins"
