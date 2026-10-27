# Strict TDD (condensed)

The rules `/flow:pair` and `flow:verifier` apply to every step. TDD is design driven by tests: the test states what the code should do, the code is the smallest thing that makes it true.

## The Three Laws

1. Write no production code until a test fails for the right reason.
2. Write no more test than is needed to fail.
3. Write no more code than is needed to pass.

## One step

1. **Safety net** (only when touching existing code): run the tests for those files first. A pre-existing failure is a stop, not something to fix silently.
2. **Red**: write one test from the approved list, run it with `Single test:` and show the real failure. A failure from a typo, missing import or broken setup is not red; fix the test setup, never the expectation.
3. **Green**: the minimum code to pass. Fake It (a hard-coded value) is valid; triangulation will force real logic. If green fails, fix the code, never the test.
4. **Triangulate**: add a second case with different input and expected output whenever the behaviour has a branch or a calculation. At least one case must produce a non-trivial result and one must take a different path. Skip it only for purely structural work with one possible output, and say so.
5. **Refactor** while green: naming, duplication, extracting pure functions. Rerun after each change; a red refactor is reverted, not patched.

## Choosing the test layer

Use the highest practical layer that fits, degrading when a layer is unavailable; never skip a test because the ideal layer is missing.

| What the step does | Layer |
|---|---|
| Pure logic, calculation, transformation | unit |
| Component behaviour, state, user interaction | integration (else unit) |
| Several parts, an API, persistence | integration (else unit) |
| Critical full user journey | e2e (else integration, else unit) |
| Visual look | manual check, listed as such |

For markdown or shell deliverables the test is a bash structural test in `scripts/tests/`.

## A real assertion

Every assertion must:

1. call the code under test,
2. compare against a concrete value taken from the acceptance criterion (never computed with the same logic as the code),
3. fail if that code were wrong.

## Banned assertion patterns

- **Tautologies**: `expect(true).toBe(true)`, `assert 1 == 1`.
- **Existence only**: `toBeDefined()`, `not.toBeNull()`, `is not None`, type checks alone; assert the value.
- **Unexplained empty results**: `== []`, `toHaveLength(0)` are valid only when the setup should yield empty and a companion case yields non-empty.
- **Ghost loops**: assertions inside a loop over a collection that may be empty; assert its length first.
- **Smoke only**: "renders without crashing" with no assertion on output.
- **Implementation coupling**: CSS class names, internal state, mock call counts; assert what the user sees or gets.
- **Trivial green**: a pass because the code path never ran (element not rendered, setup does not trigger it). Real green means the code ran and produced the expected output.

## Mocks

- Up to 3 mocks per test file is healthy; 4-6, extract a pure function; 7 or more, wrong layer.
- Extract before mocking: test a transformation or condition as a pure function, with no mocks.

## Changing existing behaviour

- Refactoring with no behaviour change: first pin current behaviour with approval tests, then refactor, rerun.
- A criterion that changes behaviour pinned by an existing test is a stop rule: ask the user before touching that test.

## Evidence per step

Test file, layer, the red output line, the green result, triangulation (cases or the reason it was skipped) and the commits.
