# Story 15: Port docs

## Story

15. As a developer, I want the README, the install.sh header and `docs/multi-agent.md` to describe the port so that I know how each agent is set up. Requires: #30, #31, #32

## Acceptance criteria

- [x] Given the README, when I read its layout table and roadmap, then the `AGENTS.md` row names the rules paths each agent really reads (the generated copies at `~/.config/opencode/AGENTS.md` and `~/.gemini/config/AGENTS.md`), and the "Port the Claude-only parts" item is checked off, with judgment-day named as the only part left for v2.
- [x] Given the install.sh header, when I read the OpenCode and Antigravity sections, then they list what the installer really does for each one (generated rules, skills, commands and agents, the hooks, and the moves into backups), matching the table in `docs/multi-agent.md`.
- [x] Given `docs/multi-agent.md`, when I set up or debug a machine, then it tells me that herdr can drop the `toolkit` key from agy's `hooks.json` (the next install puts it back), that any extra file in OpenCode's `plugins/` dir hung `opencode run --standalone` on 2.2.2 (so keep probes inside `toolkit.ts`), and that agy work is frozen with OpenCode as the secondary agent.

## Plan

- README: fix the `AGENTS.md` row and close the port roadmap item, with a pointer to v2 for judgment-day.
- install.sh: rewrite the comment header only, describing each target from what the script does today.
- `docs/multi-agent.md`: add the herdr note and the plugin-file hang note to the manual setup section, plus one status line about the agy freeze.
- Check each statement against the code and the story logs it cites; `make check` stays green.

## Out of scope

- The neutral line in the source `AGENTS.md` (R3-11): left out by the user; story #31's rule lines already cover the raw copy.
- Any change to install.sh behaviour, the generator, the goldens or the skills.
- Re-running agy or OpenCode checks; the docs cite the results already recorded.

## Suggestions (your call)

- None.

## Size

small
Risk: none

## Log

- L1 request: /flow:story 15
- L2 assumptions: the agy `mcp_config.json` line already exists in `docs/multi-agent.md` and stays as is; the agy freeze note comes from backlog #47 (user decision, 2026-11-02); the hang is documented for OpenCode 2.2.2, the version it was seen on (plan-review-4, story 20 L43).
- L3 user: leave the R3-11 `AGENTS.md` line out of this story.
- L4 pair step 1 (mode B): 865bb51 red test (README AGENTS.md row); README fixed, test green, but `make check` fails shellcheck SC2088 (literal `~/` in quotes) on the committed test; stopped (stop rule 3) to ask before adding a `# shellcheck disable=SC2088` line, assertions unchanged.
- L5 user: add a file-level shellcheck directive (86a9393, lint only, assertions unchanged; SC2016 joined it in 8f97d01 before that test was committed).
- L6 cycles (mode B): 865bb51 + 86a9393 → 4102164 README AGENTS.md row names `~/.config/opencode/` and `~/.gemini/config/`; d018a79 → a2a74ed port roadmap item checked, judgment-day left for v2; d015fb6 → 7834b7a install.sh header lists generated rules, skills, commands, agents, `toolkit.ts`, the `hooks.json` merge, `GEMINI.md` and `skills-backup/` moves, engram and version warnings; 8f97d01 → adfad3a multi-agent.md status line (agy frozen, OpenCode secondary), plugin-file hang (2.2.2) and herdr notes. Step 4 took one retry: the doc wording changed, not the test. Tamper checks empty on every step. Triangulation skipped: structural doc checks with one possible output each.
- L7 evidence: `bash scripts/tests/port-docs.test.sh` → All cases passed; `make check` → All checks passed (7 steps). Plan item 10 marked done.
- L8 Risk: none.
