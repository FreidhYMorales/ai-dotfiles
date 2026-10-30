# Story 28: read-only OpenCode verifier

## Story

28. As a developer, I want the OpenCode `flow-verifier` limited to read-only shell commands (`git log/diff/show`, `rg`, `make check`) and unable to start subagents so that the verifier stays read-only outside Claude. Requires: #27

## Acceptance criteria

- [ ] Given `./install.sh --target opencode`, when the `flow-verifier` subagent runs `git log`, `git diff`, `git show`, `rg` or `make check`, then it runs without a prompt, and any other shell command (e.g. `git commit`, `rm`) asks me first (resolved permissions shown by `opencode debug agents`; manual check, recorded in the story log).
- [ ] Given the installed `flow-verifier`, when it tries to start a subagent, then OpenCode refuses it (resolved permission `subagent: deny`).
- [ ] Given a change to the verifier's permissions in the generator, when I run `make check` without regenerating the goldens, then the check fails and names the verifier file.

## Plan

- The generator writes a `bash` permission for the OpenCode verifier: ask by default, allow the read-only patterns and `make check`.
- The subagent block keeps the key OpenCode 2.2.2 resolves to `subagent` (verified: `task: deny` already resolves to `subagent: deny`), now pinned by the golden.
- The OpenCode verifier golden is regenerated; the plan reviewer is untouched.
- `docs/multi-agent.md` names the verifier's shell limit.

## Out of scope

- The plan reviewer's shell (it needs `pandoc`/`pdftotext`; read-only by prompt, as story 08 noted).
- Agy agents: no shell tool there yet (#17).
- Other projects' `Test command:` values: anything but `make check` asks.
- #29 (make eval pending), #12 (role model map).

## Suggestions (your call)

- none

## Size

normal
Risk: item 2 (shell commands a subagent may run without asking), item 6 (the live ask prompt is a manual check)

## Log

- L1 request: "/flow:story 28"
- L2 assumptions for approval: only the verifier changes; `task: deny` stays the key because `opencode debug agents` shows OpenCode 2.2.2 resolving it to `subagent: deny` (the binary maps `task` → `subagent` and `bash` → `shell`), so C2 holds today and this story pins it; allow patterns are `git log*`, `git diff*`, `git show*`, `rg *`, `make check` exactly as the plan (item 5, R6-6) lists; the default for other commands is `ask`, not `deny`.
- L3 approved by the user ("si").
- L4 test list approved ("si"): 1 OpenCode verifier golden gets the `bash` block (ask by default, five allow patterns) and keeps `task: deny` (C1-C3); 2 plan reviewer golden untouched (existing); 3 manual `opencode debug agents` after install (C1, C2). The changed golden is a story-28 criterion, approved with the list.
- L5 steps: a505989 → 4e7c0b0 (golden + generator), docs f4e8f75; `make check </dev/null` → "All checks passed (7 steps)".
- L6 manual check 3 (C1, C2) after `./install.sh --target opencode`: `opencode debug agents` first showed no shell rule because it asked the running `opencode serve --service` (started before the install, stale config). `opencode debug agents --standalone` resolves `flow-verifier` to: subagent * deny; shell * ask; shell `git log*`, `git diff*`, `git show*`, `rg *`, `make check` allow. Pass. Probe: OpenCode 2.2.2 accepts both `bash:` and `shell:` keys and the pattern-object form. A running OpenCode service keeps old agent permissions until it restarts.
- L7 verifier (fresh): FAIL on item 2. The allow globs take any arguments: `rg --pre=COMMAND` runs a program with no prompt; `git log/diff/show --output=<file>` writes any file with no prompt (confirmed here: `git log -1 -p --output=<file>` wrote it), bypassing `edit: deny`; `--ext-diff` and shell redirection unverified. Precedence checked in the OpenCode 2.2.2 binary: the last matching rule wins (`findLast` over action and resource, default ask), so rules placed after the allows override them. Stop rule 1: the fix changes the approved pattern list.
- L8 correction approved ("si"): add after the allows `"rg *--pre*": deny`, `"git *--output*": deny`, `"git *--ext-diff*": deny`, `"*>*": ask`.
- L9 correction b228cf6 → c0c12f7; `make check </dev/null` → "All checks passed (7 steps)"; `opencode debug agents --standalone` on the fresh generation resolves the shell rules in order: * ask; git log*/diff*/show*, rg *, make check allow; rg *--pre*, git *--output*, git *--ext-diff* deny; *>* ask.
