# `make check` template

Every project exposes ONE quality gate: `make check`. Agents and CI run it; work is done only when it passes. The toolkit Stop hook runs it before an agent may finish a turn with uncommitted changes.

## Rules

- `check` runs, in order: format check (no rewrite), lint, typecheck (when the language has one), tests. Drop a step only when the stack has no such tool; say so in a comment.
- Read-only and non-interactive: no `--watch`, no prompts, no auto-fix. Put fixers in a separate `fmt` target.
- Wrap the stack's native tools (npm scripts, cargo, uv...) instead of duplicating their config. Even when `make` is unusual for the stack, the Makefile is a thin wrapper and stays.
- At least one smoke test exists from the first commit, so `check` is green from day one.
- Never weaken a check (disable a rule, skip a test, loosen types) to make it pass. Fix the code, or ask.

## Skeleton

```make
.PHONY: check fmt
check:
	<format check>
	<lint>
	<typecheck>
	<tests>
fmt:
	<format write>
```

## Per-stack recipes

| Stack | Format check | Lint | Typecheck | Tests | `fmt` |
|---|---|---|---|---|---|
| Node / TS (pnpm) | `pnpm exec prettier --check .` | `pnpm exec eslint .` | `pnpm exec tsc --noEmit` | `pnpm exec vitest run` | `prettier --write .` |
| Python (uv) | `uv run ruff format --check .` | `uv run ruff check .` | `uv run mypy .` or `uv run pyright` | `uv run pytest` | `ruff format .` |
| Go | `test -z "$$(gofmt -l .)"` | `go vet ./...` | (compiler; covered by vet/test) | `go test ./...` | `gofmt -w .` |
| Rust | `cargo fmt --check` | `cargo clippy --all-targets -- -D warnings` | (compiler; covered by clippy) | `cargo test` | `cargo fmt` |
| Shell | `shfmt -d .` | `shellcheck $$(git ls-files '*.sh')` | n/a | `bats test/` or `*.test.sh` runner | `shfmt -w .` |

## Smoke tests

| Stack | File | Content |
|---|---|---|
| Node / TS | `src/smoke.test.ts` | `import { expect, test } from "vitest"; test("smoke", () => expect(1 + 1).toBe(2));` |
| Python | `tests/test_smoke.py` | `def test_smoke(): assert 1 + 1 == 2` |
| Go | `smoke_test.go` | `func TestSmoke(t *testing.T) { if 1+1 != 2 { t.Fatal("math") } }` |
| Rust | `tests/smoke.rs` | `#[test] fn smoke() { assert_eq!(1 + 1, 2); }` |

Prefer a smoke test that touches real code (the entry module imports, the app factory builds) once it exists.
