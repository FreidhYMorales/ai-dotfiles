# Story 25: agy agent mapping for engram, command policy and the pair verifier line

## Story

25. As a developer, I want agy agents to declare engram under `mcpServers:` and a `commandExecutionPolicy` each, and the agy `flow-pair` to say a high-risk story ends in NEEDS DECISION while its verifier has no shell tool, so that agy agents reach memory and never pretend to verify. Requires: #08, #16

## Acceptance criteria

- [ ] Given an agent source that lists an `mcp__engram__*` tool, when it is generated for Antigravity, then engram is declared under `mcpServers:` and no engram name is left in `tools:`; an agent with no engram tool gets no `mcpServers:`.
- [ ] Given any agent, when it is generated for Antigravity, then its frontmatter sets `commandExecutionPolicy: off` while it has no shell tool (every agent today, so the `flow-plan-reviewer` golden gains that line).
- [ ] Given the `pair` skill, when it is generated for Antigravity, then its check step says a high-risk story ends in NEEDS DECISION because the agy verifier has no shell tool to run the `Test command:`, and the OpenCode `flow-pair` has no such line.

## Plan

- The agy agent mapping treats `mcp__engram__*` tools as one engram `mcpServers:` entry instead of registry tool names; other unmapped tools still stop the generator.
- The same mapping writes `commandExecutionPolicy`, `off` while no Claude tool maps to an agy shell tool.
- The agy words step adds one generated line to pair's verifier step while Bash has no agy name; never a hand edit.
- Tests use fixture sources (as stories 08 and 24 do): an agent with an engram tool, and a `pair` skill with the verifier step; the `flow-plan-reviewer` golden is regenerated.

## Out of scope

- Generating `flow-pair`, `flow-verifier` or any other loop skill for real (#09); here `pair` is only exercised through a fixture.
- The empty-report rule in the source `pair` skill and its `make eval` (#26).
- Proving `mcpServers:` or `commandExecutionPolicy` in a live agy run, or a shell tool name (#17).
- The role model map (#12); `model: pro` stays.

## Suggestions (your call)

- `agy_tools` already returns nothing for `Bash`; the same fact can drive both the `commandExecutionPolicy` value and the pair line, so they flip together when #17 proves `run_command`.

## Size

normal
Risk: item 3 (agy agent frontmatter agy parses), item 5 (generator output agy loads), item 6 (agy accepting the new keys is only proven live in #17)

## Log

- L1 request: "/flow:story 25"
- L2 user decision: engram goes under `mcpServers:` only for agents that list an `mcp__engram__*` tool (plan Core model wording), not for every agy agent.
- L3 assumptions for approval: the engram entry is name `engram`, command `engram`, args `mcp --tools=agent` (the OpenCode entry in `docs/multi-agent.md`); `off` is the policy value the plan names, unproven until #17; the pair line is tied to Bash having no agy name.
- L4 approved by the user ("si").
- L5 built (pair, mode C): f361214 → 798a3e2 engram under `mcpServers:` for agents with an `mcp__engram__*` tool; 1f977d9 pin: no `mcpServers:` without engram (a mutation writing it always fails it); 357410c (golden red) → 3bf4d4a `commandExecutionPolicy: off` on every agy agent; dcb8b51 → b456554 agy `agy_words` appends the NEEDS DECISION sentence to the line invoking `flow-verifier`; 13b4b28 pin: OpenCode has no such line (a mutation applying agy words to OpenCode fails it); 6ea906f shellcheck directive only.
- L6 evidence: `make check` → "All checks passed (7 steps)"; `gen-agents.test.sh` → "All cases passed". Verifier: PASS (all three criteria, commit order, tamper check, assertions). Live agy acceptance of `mcpServers:` and `commandExecutionPolicy: off` stays with #17.
- L7 Risk: item 3 (agy agent frontmatter agy parses), item 5 (generator output agy loads), item 6 (agy accepting the new keys is only proven live in #17)
