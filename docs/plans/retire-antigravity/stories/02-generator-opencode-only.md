# Story 02: the agent generator produces only OpenCode output

## Story

02. As a developer, I want the agent generator to produce only OpenCode output so that a skill change touches one golden set. Requires: #01

## Acceptance criteria

- [ ] Given the repo's skills, when I run the generator, then its output holds no `antigravity/` directory and every OpenCode file is byte for byte what it was (`git diff main -- scripts/gen-agents/golden/opencode` is empty).
- [ ] Given a models file whose role has no `opencode` entry, when I run the generator, then it fails and the error names `opencode`; the shipped models file has no `antigravity` key.
- [ ] Given an agent that uses an engram tool, when I run the generator, then it exits 0 and the OpenCode reviewer file holds no `mcp__engram__`.

## Plan

- The generator loses every agy function, call and comment (header included), and the `antigravity` branch of the model lookup; the OpenCode path is untouched.
- The models file drops its `antigravity` key; the antigravity golden set is deleted; the golden check keeps passing on OpenCode alone.
- Test triage per the plan's shared-file rule: agy blocks and loop entries leave the generator test and the `flow-pair`, `flow-new-repo-tiers` and `no-openspec` tests; OpenCode assertions stay.
- Pre-approved rewrites from the plan: the agy tool-map case is deleted (coverage loss accepted); the stale-golden case expects only OpenCode files; the stale-key map case loses its antigravity key; the missing-model case expects a failure naming `opencode`; the OpenCode "no agy line" guard is deleted while its neighbour stays; the `mem` block keeps only `mem: generator exits 0`, rewritten as in criterion 3.
- Closing scan `rg -n -i 'agy|antigravity|\.gemini'` over the files this story owns shows only the regression RED (the generated tree without `antigravity/`).

## Out of scope

- The installer and `ai-update` (story 01, done); the hook adapters and toolkit bump (story 03); README, `docs/multi-agent.md`, `no-agy` test (story 04).
- Any change to the generated OpenCode output or the OpenCode golden set.
- New tool mapping or model validation for OpenCode to replace the lost agy checks.

## Suggestions (your call)

- Assumption: `install.sh` no longer links anything from `build/agents/antigravity` (story 01 removed `link_generated antigravity`), so dropping that tree cannot break an install; a `--target all` install test run in this story confirms it.

## Size

normal
Risk: item 3 (generated OpenCode output)

## Log

- L1 request: /flow:story 02
- L2 user: approved the test list (mode C); test 3 (missing-entry) ran before test 1 so the green of test 1 would not break the old missing-entry case.
- Commits: 023d167 test (pre-approved removal of agy-only cases in gen-agents, flow-pair, flow-new-repo-tiers, no-openspec; single-entry loops unrolled for SC2043); 8f14cad test (a missing opencode entry fails naming opencode); 341042c test + ae5efc6 feat (generated tree has no antigravity/; gen.sh agy code and golden/antigravity removed); 0dcdc46 test + dbafdca feat (models.json has only an opencode reviewer entry); 0911e0f test (engram tool neither breaks nor leaks into OpenCode generation).
- Tests 8f14cad and 0911e0f passed on first run against the current generator; each was shown red against a mutant (error without the target; OpenCode agent copying the Claude tools line) before committing (no feat of their own).
- Hard gate: `git diff main -- scripts/gen-agents/golden/opencode` empty.
- Closing scan over scripts/gen-agents and the four test files: two regression lines only, gen-agents.test.sh:42 (no antigravity/ directory) and :207 (stale names only OpenCode files).
- Evidence: `make check </dev/null` on 0911e0f: "All checks passed (8 steps)". Note: no-openspec.test.sh hangs when stdin is open (its `rg -l openspec` has no path); pre-existing, not changed here.
- Verifier: PASS (criteria 1-3 PASS with mutants in a scratch clone; commit order PASS; tamper PASS; assertions PASS; its own `make check` passed). Refs and HEAD unchanged across the run.
- Risk: item 3 (generated OpenCode output)
