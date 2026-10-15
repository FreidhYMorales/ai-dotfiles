# Work package NN: <title>

Owner: <name> · Estimate: <n> dev-days · Due: <date> · Depends on: <packages or "none">

## Paste this at the top of your AI chat

> You are helping me implement the work package below. Respect the contracts exactly; do not change them.
> Do not add dependencies outside the allowlist. Only create or edit the files listed under "Files to deliver".
> Fill in the skeleton bodies, keep the signatures. Make all tests pass. If something in the contract seems wrong,
> tell me instead of changing it.

## Context (5 lines max)

<What the project is, what this piece does, who uses it, where it fits.>

## Scope

- In: <bullets>
- Out of scope: <bullets — things NOT to touch or build>

## Contracts (frozen — do not change)

```<lang>
<inline copy of the relevant types, schema, function I/O, seed format>
```

## Files to deliver

| Path | Purpose |
|---|---|

## Skeletons

```<lang>
// <path>
<exact signatures, empty bodies, TODO comments>
```

## Allowed dependencies

<Only these: ... Anything else needs approval from <CLI user>.>

## Conventions

<Naming, formatting, error handling, folder layout, language of UI copy.>

## Tests (run them before delivering)

Run: `<command>`

| Case | Input | Expected output |
|---|---|---|

```<lang>
<runnable test file content, or path if it already exists in the repo>
```

## How to deliver

1. GitHub web: fork or branch `<branch-name>`, upload the files under "Files to deliver", open a PR to `main`.
   Or: send the files to <CLI user>.
2. In the PR description, explain your change in 3 lines: what you did, what you could not do, anything that surprised you.
3. CI must pass (tests, lint, typecheck).

## Done when

- [ ] All tests pass locally
- [ ] Only listed files changed
- [ ] No contract or dependency changes
