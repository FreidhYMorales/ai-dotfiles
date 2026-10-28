# Story 02: gentle-ai skill backups leave the discovery dirs

## Story

02. As a developer, I want gentle-ai's moved-aside skills kept outside the skills discovery dirs so that they never shadow the repo skills and nothing of gentle-ai is lost. Requires: #01

## Acceptance criteria

- [x] Given a sentinel skill in each candidate dir (`~/.gemini/config/skills/`, `~/.gemini/antigravity-cli/skills/`, `~/.gemini/skills/`), a `.bak-*` copy and two skills with the same `name:`, when I ask `agy -p` which skills it has, then I get a recorded table of the dirs agy 1.4.7 discovers, whether a `.bak-*` dir is discovered, and which copy wins a name clash (manual check).
- [x] Given `./install.sh --target antigravity`, when it runs, then the repo skills are linked only in dirs the check proved, and this repo's own skill links in unread dirs are removed.
- [x] Given real `.bak-*` skill dirs in a discovery dir, when I install (once or twice), then each is moved with its content intact into a backup dir outside every discovery dir, none is deleted or overwritten, and the output names each move.

## Plan

- Run the sentinel check by hand like story 01 (back up, plant, `agy -p`, restore) and record the table in `docs/multi-agent.md`.
- Pin the proven skills layout and the backup move in the antigravity sandbox install tests first (red), then change the installer.
- Only this repo's own symlinks are ever removed; real dirs are only moved, never deleted.
- A name already taken in the backup dir gets a new name instead of overwriting.
- Fix the Antigravity skills row of `docs/multi-agent.md` to match the check.

## Out of scope

- gentle-ai's active (non-`.bak`) copies in `~/.gemini/skills/`: recorded by the check only; if they win a clash, that becomes a new story.
- OpenCode skills (no `.bak-*` dirs there today).
- The generator, renamed `flow-`/`toolkit-` skill dirs, `CLAUDE_ONLY_SKILLS` (stories 08 and later).
- Deleting anything of gentle-ai.

## Suggestions (your call)

- agy's bundled docs put skills at `<root>/skills/` and name `~/.gemini/config/` as the global root, so `~/.gemini/config/skills/` (it does not exist yet) is the likely winner; the check decides.
- Story 01 left the same "remove only our own link" logic in two places; this story adds a third, so a small helper would pay off here.

## Size

normal
Risk: item 1 (moves gentle-ai's skill dirs), item 5 (install script), item 6 (what agy discovers is only checkable by hand)

## Log

- L1 request: "/flow:story 02"
- L2 assumptions for approval: the skills path fix (criterion 2) belongs here, because the backlog has no story for it although plan item 0 covers "rules and skills" (a gap in the backlog I made); 18 `*.bak-20261023-170049` dirs exist today, all in `~/.gemini/antigravity-cli/skills/`; the backup dir is `~/.gemini/antigravity-cli/skills-backup/` (plan Core model), and it is moved only if the check shows it is outside discovery.
- L3 approved by the user ("si").
- L4 test list approved (1 manual, 4 integration; flipping the pinned skills assertions pre-approved if the dir changed).
- L5 manual sentinel check (C1), two `agy -p` runs plus a control run: `~/.gemini/config/skills/`, `~/.gemini/antigravity-cli/skills/` and `~/.gemini/skills/` all discovered; a `*.bak-*` dir is discovered by its `name:`; on a name clash the `antigravity-cli/skills/` copy wins; `antigravity-cli/skills-backup/` is not discovered. Every planted probe removed; the 18 real `.bak-*` dirs untouched. Recorded in `docs/multi-agent.md` (`1a20c78`).
- L6 consequences approved by the user: the skills path stays (already the winning dir; existing assertions cover C2); the "remove own links in unread dirs" test dropped (no unread dir).
- L7 cycles (mode C): 5f43850→b0aa309 `.bak-*` moved to `skills-backup/` with content; 6d18e97→2dffc18 a taken name gets a numeric suffix, never overwritten or nested.
- L8 verifier: FAIL on C3 (the sweep ran before `link_skills`, whose `link_file` renames a clashing user dir to `*.bak-*`, so that backup stayed discoverable until a second install). Correction: feb80c1→02cfca9 sweep after linking; one install leaves no backup in discovery, a second install moves nothing.
- L9 verifier recheck: Verdict: PASS. Notes: the sweep scans only `antigravity-cli/skills/` (all current backups are there); dry-run still prints the move lines.
- L10 tests: `bash scripts/tests/install.test.sh` → All cases passed; `make check` → All checks passed (7 steps).
- L11 Risk: item 1 (moves gentle-ai's skill dirs), item 5 (install script), item 6 (what agy discovers is only checkable by hand).
