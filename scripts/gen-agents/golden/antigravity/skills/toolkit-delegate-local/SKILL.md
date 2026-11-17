---
name: toolkit-delegate-local
description: "DRAFT, explicit use only: /toolkit-delegate-local. Hand a narrow, checkable coding task to a local model (pi + ollama inside pi-box), then verify and apply its diff. Saves Claude quota and context; costs wall time."
license: MIT
metadata:
  author: FreidhYMorales
  version: "0.1"
---

## Activation Contract

Load only when the user runs `/toolkit-delegate-local` or explicitly asks to delegate a task to the local model. Never delegate on your own initiative while this skill is a draft.

## Hard Rules

- Delegate only tasks with an objective check you can run yourself (a test, `make check`, a reproducible command). No check, no delegation.
- The worker runs in a throwaway clone inside `pi-box`; never in the real repo, never with `PI_BOX_NETWORK=host`.
- Never trust the worker's report. Re-run the check yourself; when it added a test, break the code on purpose and confirm the test fails.
- Commits and PR bodies carry no AI attribution; record that a worker wrote the change in engram, not in git.
- One task per worker run: pi runs once per task; a second run is a new task, not a retry that feeds back the failure. If it fails twice, do the task yourself and record why in engram.

## Decision Gates

| Situation | Action |
|---|---|
| Language/level marked "local" in the delegation table | Delegate |
| Marked "Claude only", or not in the table | Do it yourself |
| Design decision, cross-cutting refactor, security-sensitive code | Do it yourself |
| Task needs files outside one project, or network | Do it yourself |
| Worker diff touches files outside the stated scope | Reject, or keep only in-scope hunks after review |

## Delegation Table

From `bench/worker/run.sh` (pass = hidden check + gate + scope), gpt-oss:20b, run of 2026-10-17: 12/20. One run per task, so treat single results as signals, not verdicts.

| Lang | L1 (one function) | L2 (2-3 files) | L3 (find the bug) |
|---|---|---|---|
| python, go, rust, c | local | not measured | local |
| bash | local + `shfmt -w` after (logic was right; format failed) | not measured | not measured |
| lua | local | Claude (wrong API use) | Claude (broke syntax) |
| typescript | Claude (ignored "leave X as is") | not measured | local |
| qml (.qml files) | Claude (wrong pragma syntax) | Claude | Claude |
| qml JS logic (.js libraries) | local | not measured | local |

Default model: gpt-oss:20b (11 GB, 100% GPU, ~300 tok/s prefill, ~21 tok/s gen). qwen3-coder:30b does not fit with pi's 32k context (RAM hit 97%).
Workers often claim "all tests pass" when they do not (4 of 8 failures): verification is mandatory.
They also delete or weaken existing tests (4 of 13 passing patches; see `docs/local-workers.md`): always diff the test files and re-run the original tests.

## Execution Steps

1. Write the task as a prompt: the behavior wanted (not the implementation), the files it may change, and the exact command that must pass: the backlog's `Single test:` command filled in for the task, the `Test command:` when the backlog has no `Single test:` or it is `none`, or `make check` when there is no backlog; never the full suite.
2. Clone outside HOME so pi-box accepts it: `git clone -q --no-hardlinks <repo> <scratchpad>/worker && cd <scratchpad>/worker`.
3. Run: `timeout 1200 pi-box --provider ollama --model <model> --no-session -p "<prompt>"`. Run it in the background; it takes minutes.
4. Review `git status --short` and `git diff`: scope, size, no unrelated edits.
5. Verify independently: run the check yourself; mutate the code to confirm new tests bite.
6. Apply: `git -C <worker> diff > <scratchpad>/worker.patch && git -C <repo> apply --check <patch> && git -C <repo> apply <patch>`, then rerun the full `Test command:` (or `make check`) once on the applied tree (allow up to 10 minutes (Claude: Bash `timeout` 600000), or run it in the background and read the result); when it is red, report the change as rejected or fix it yourself.
7. Save an engram note: task, model, time, verdict, anything the worker got wrong.

## Output Contract

The task, model and wall time; the diff summary; the independent check result; applied or rejected, and why.

## References

- `bin/pi-box` — sandbox: project-only writes, ollama-only network.
- `bench/worker/` — the benchmark that fills the delegation table.
