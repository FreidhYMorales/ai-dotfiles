# Story 45: agy maps `Glob` to `find_by_name`

## Story

45. As a developer, I want the generator to map `Glob` to `find_by_name` for agy, so that the agy plan reviewer can list files the way it does in Claude. Requires: #42

## Acceptance criteria

- [x] Given a source agent whose tools include `Glob`, when it is generated for Antigravity, then its `tools` list includes `find_by_name`, `Bash` still maps to nothing and `commandExecutionPolicy` stays `off`.
- [x] Given the installed build, when `agy -p` asks the `flow-plan-reviewer` subagent to list the files of a small plan folder, then the subagent is built, calls `find_by_name` and returns the file names, with no registry error in agy's log (manual check).
- [x] Given the change, when I read `docs/multi-agent.md` and the plan, then they say the agy reviewer has `find_by_name` and still lacks a shell tool (#46).

## Plan

- The agy tool map learns one more name: `Glob` becomes `find_by_name`; `Bash` stays unmapped until #46.
- The reviewer's golden gains the new tool; a generator test pins the mapping first.
- After `./install.sh`, one live `agy -p` run of the reviewer proves agy still builds it, since an unknown tool would make it vanish silently.
- The docs line on the agy reviewer's tools and the plan's tool-names row are brought in line.

## Out of scope

- `Bash` → `run_command` and any `commandExecutionPolicy` change (#46).
- Bringing back the agy verifier (#47).
- OpenCode's tool mapping.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 5, 6 (the generated agent is installed into agy's config; whether agy builds it is only checkable by hand)

## Log

- L1 request: /flow:story 44
- L2 split: #44 bundled three changes (Glob mapping, Bash mapping with an unproven `commandExecutionPolicy` value, the verifier decision), more than 3 criteria; split → #45, #46, #47, refining #45 first.
- L3 assumptions for approval: only `flow-plan-reviewer` is generated for agy and is the only agent affected; Claude runs the live `agy -p` check itself (`find_by_name` needed no permission flag in #42).
- L4 approved: "si apruebo el plan".
- L5 cycle (mode C): e3f76e4 test (three frontmatter asserts; the reviewer's agy golden gains `find_by_name` and the test comment drops `Glob`, both approved in the test list; red: "matches golden", "this repo verifies", "agy reviewer gets find_by_name for Glob", plus the golden-derived "map: agy flow-plan-reviewer uses flash" the verifier replayed) → 70312d8 feat (`Glob) echo find_by_name`). Tamper check empty. `make check`: "All checks passed (7 steps)".
- L6 manual (agy 1.4.12, after `./install.sh`, `agy -p` outside any repo, no permission flag): the main agent invoked `flow-plan-reviewer`; the subagent called `find_by_name` and returned the four file names of a temp plan folder, including a random suffix the prompt did not hold; no registry error in the `--log-file` log (209 lines) or the transcripts.
- L7 docs: 1a00d69 (`docs/multi-agent.md` reviewer tools line, plan rows; split #44 notes now point at #46 and #47).
- L8 verifier: PASS.
- Risk: item 5, 6 (the generated agent is installed into agy's config; whether agy builds it is only checkable by hand)
