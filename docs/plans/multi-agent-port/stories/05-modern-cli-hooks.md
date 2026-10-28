# Story 05: prefer-modern-cli blocks legacy tools in OpenCode and Antigravity

## Story

05. As a developer, I want `prefer-modern-cli` to block legacy tools in OpenCode and Antigravity so that every agent follows the same tool rules.

## Acceptance criteria

- [ ] Given Antigravity runs a shell command with a legacy tool (e.g. `ls`, `grep`), when the toolkit PreToolUse hook sees it, then the command is denied with the same message Claude gets (e.g. "Use eza instead of ls…"); modern tools and `# legacy-cli` pass, and a malformed payload is denied.
- [ ] Given OpenCode runs its bash tool with a legacy tool, when the toolkit plugin sees it, then the call is blocked with the same message; modern tools and `# legacy-cli` pass, other tools are untouched, and a malformed call is blocked.
- [ ] Given `./install.sh --target opencode,antigravity` (once or twice), when it runs, then agy's `~/.gemini/config/hooks.json` gains a `toolkit` key with the PreToolUse hook while every other key (herdr) stays byte-identical, and OpenCode gets a `toolkit` plugin linked next to `engram.ts` and the herdr plugin, which stay untouched.

## Plan

- Pin each criterion in tests first (red): adapter tests fed the documented payload of each target, installer sandbox tests for the merge and the link.
- The Claude hook stays the single source of the rule; each target gets a thin adapter that turns its payload into the hook's input and the hook's block into the target's deny.
- Only the two new PreToolUse adapters fail closed; the Claude hook and its tests stay unchanged and fail-open.
- The installer merges only its own `toolkit` key with jq and links only its own plugin file; it never rewrites herdr's or engram's files.
- Record in `docs/multi-agent.md` that the Hooks row now has `prefer-modern-cli` in both targets.

## Out of scope

- The other hooks (Stop gate story 06, session-start and `pause` story 07) and the rest of the neutral contract (`source`, context/message split, reentry, timeouts).
- The generator and the `build/agents/` layout (story 08 on).
- A live smoke in agy or OpenCode beyond an optional manual check (story 13).

## Suggestions (your call)

- none

## Size

normal
Risk: item 1 (merges into agy's hooks.json that herdr also writes), item 5 (install script, runtime config), item 6 (the real agy payload can only be confirmed by hand)

## Log

- L1 request: "/flow:story 05"
- L2 assumptions for approval: agy's PreToolUse payload and answer follow its bundled docs (`toolCall.name == "run_command"`, `toolCall.args.CommandLine`; stdout `{"decision":"deny","reason":…}`); a capture from a real agy run waits for the quota reset (~54 h), so the adapter test uses the documented shape. OpenCode is v2.1.4: plugin in `~/.config/opencode/plugins/`, `tool.execute.before` blocks by throwing, bash tool args `command`; a real payload is captured once in OpenCode before the test is written. Adapters call the existing `prefer-modern-cli.sh` rather than a new "core", the simplest thing that keeps one rule; the full neutral contract grows in stories 06-07.
- L3 approved by the user ("si").
