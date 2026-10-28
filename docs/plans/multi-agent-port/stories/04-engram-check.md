# Story 04: install.sh says when engram is not registered

## Story

04. As a developer, I want install.sh to tell me when engram is not registered in OpenCode or Antigravity so that memory is shared across all three agents.

## Acceptance criteria

- [x] Given an OpenCode config with no enabled `mcp.engram` entry (or no config file), when I run `./install.sh --target opencode`, then the output says engram is not registered in OpenCode and names the manual step (`engram setup opencode`), and the install still succeeds.
- [x] Given `agy mcp list` does not list `engram` (or `agy` is not installed), when I run `./install.sh --target antigravity`, then the output says engram is not registered (or cannot be checked) in Antigravity and names the manual step (`engram setup antigravity-cli`), and the install still succeeds.
- [x] Given engram is registered in both, when I install either target, then no engram warning is printed and no agent config file is changed.

## Plan

- Pin each criterion in the sandbox install tests first (red), with a stub `agy` like the existing `claude` stub.
- OpenCode: read `~/.config/opencode/opencode.json` with jq; never write it.
- Antigravity: ask `agy mcp list` only (two `mcp_config.json` files exist, so the files are not the truth); never write either.
- A warning only: never run `engram setup`, never fail the install.
- Fix the Engram MCP row and the "add it by hand" paragraph in `docs/multi-agent.md`.

## Out of scope

- Running or wrapping `engram setup` (plan: verify only).
- Checking that engram actually answers (a live MCP call).
- Claude Code (engram comes from its plugin).
- Story 03's subagent work.

## Suggestions (your call)

- none

## Size

normal
Risk: item 5 (install script)

## Log

- L1 request: "okay, vamos con el 04, ahorita corro el install yo manualmente"
- L2 assumptions for approval: an `mcp.engram` entry with `"enabled": false` counts as not registered; a missing `agy` binary warns "cannot check" instead of failing; the warning text names `engram setup <agent>` because the plan makes it the documented manual step; today both are registered by hand (`opencode.json` `mcp.engram`, `agy mcp list` shows `engram`).
- L3 approved by the user ("si").
- L4 test list approved (6 integration tests; the sandbox gains a stub `agy` whose `mcp list` reads a state file, engram listed by default, so the real agy never runs in tests).
- L5 cycles (mode C): 2929b69→c661029 OpenCode warns on a missing config; a265f08 (disabled entry) and f6ec4c3 (registered: no warning, `opencode.json` hash unchanged) test-only, each shown to fail against a temporary mutation of `install.sh`; 42f0446→4531897 agy without engram warns; 3a80e80→1b42edf no agy says it cannot check; bcb152e (agy with engram: no warning) test-only, mutation-checked. Test 6's first assertion matched `engram-backup` lines and was fixed before its commit. c5c1448 docs.
- L6 verifier: Verdict: PASS. Notes: no test hashes an agy `mcp_config.json` (the code only runs `agy mcp list`); `pipefail` with `rg -q` could in theory give a false warning, never a failed install; a `disabled` row in `agy mcp list` still counts as registered.
- L7 tests: `bash scripts/tests/install.test.sh` → All cases passed; `make check` → All checks passed (7 steps).
- L8 Risk: item 5 (install script).
