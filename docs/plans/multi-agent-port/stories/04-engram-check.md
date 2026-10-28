# Story 04: install.sh says when engram is not registered

## Story

04. As a developer, I want install.sh to tell me when engram is not registered in OpenCode or Antigravity so that memory is shared across all three agents.

## Acceptance criteria

- [ ] Given an OpenCode config with no enabled `mcp.engram` entry (or no config file), when I run `./install.sh --target opencode`, then the output says engram is not registered in OpenCode and names the manual step (`engram setup opencode`), and the install still succeeds.
- [ ] Given `agy mcp list` does not list `engram` (or `agy` is not installed), when I run `./install.sh --target antigravity`, then the output says engram is not registered (or cannot be checked) in Antigravity and names the manual step (`engram setup antigravity-cli`), and the install still succeeds.
- [ ] Given engram is registered in both, when I install either target, then no engram warning is printed and no agent config file is changed.

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
