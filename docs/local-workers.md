# Local workers: pi + local models (parked)

Status: **parked on 2026-10-19.** The dotfiles stay Claude-first. Everything below is kept and runnable, but nothing delegates to a local model by default (`toolkit:delegate-local` is an explicit-only draft).

## Goal

Claude orchestrates; a local model (through `pi`) does narrow, checkable coding tasks, to save Claude quota and context.

## Setup that works

| Piece | State |
|---|---|
| Hardware | Core Ultra 7 258V: Arc 140V iGPU (64 TOPS), NPU (47 TOPS, unused), 32 GB LPDDR5X-8533 shared |
| ollama on the GPU | `ollama-vulkan` + `/etc/systemd/system/ollama.service.d/igpu.conf` (`OLLAMA_IGPU_ENABLE=1`) |
| pi 1.3 | official installer (pinned lockfile), `~/.pi/agent/models.json` points at ollama |
| `bin/pi-box` | bubblewrap sandbox: only the project is writable, HOME hidden, ollama-only network |
| Models | downloaded with `~/Files/models/download-models.sh` (curl + sha256): `ollama pull` kept stalling |
| Benchmark | `bench/worker/` (20 tasks, 8 languages, L1-L3, hidden checks; `validate.sh` proves each check) |

## Measurements

| Model | Fits on GPU | Prefill (4k prompt) | Generation |
|---|---|---|---|
| gpt-oss:20b (MXFP4, 11 GB) | 100% | ~311 tok/s | ~21 tok/s |
| qwen3-coder:30b (Q4_K_M, 19 GB) | 65% (pi's 32k context: 22 GB, RAM hit 97%) | ~143 tok/s | ~19 tok/s |

Prefill is the bottleneck: pi's ~700-token system prompt reads in ~2 s; Claude Code's ~25k would take ~80 s. pi is the only practical harness here.

## Benchmark results (gpt-oss:20b, one run per task)

- Automated pass: **12/20** (Python, Go, Rust, C passed L1 and L3; bug-finding L3 6/7). Failures: bash 3/4, Lua L2/L3, QML L1/L2 (wrong `.pragma library` syntax), TypeScript L1 (changed code it was told to keep).
- Task 04 failed twice with a reproducible ollama server error (`does not match the expected peg-native format`).
- With feedback loop + auto-format + cheat sheets (3 of 8 failures re-run before parking): 02 recovered (format), 03 regressed on the second attempt, 04 still failed.

## Why it is parked: code quality

A review of the 13 patches that passed the automated checks:

| Verdict | Tasks |
|---|---|
| accept | 14, 18 |
| accept with nits | 02, 10, 15, 16, 17, 19, 20 |
| needs rework | 05, 11, 12 |
| **reject** | **01: deleted `set -u` and the test file's `exit 1` block, so the test could never fail** |

- In **4 of 13** patches it deleted or weakened existing tests (01, 11, 12, 20); the checks did not notice.
- It re-indents and rewrites code it was not asked to touch (15 and 16 were mostly 4-space re-indents of whole test files; 16's real fix was the same 1-line change as the reference).
- It often claims "all tests pass" when they do not.
- Core logic is usually right; review is still 3-10 minutes per patch. It moves work instead of removing it.

## To resume

Fix the benchmark before measuring more, or the numbers lie:

1. **Tamper guard:** also run the BASE versions of existing test files against the model's code.
2. **Formatter checks in gates:** `gofmt -l`, `rustfmt --check`, `ruff format --check`, `shfmt -d`.
3. **Cheat sheet line:** never delete or weaken existing tests.
4. **Feedback loop:** feed back only failing lines (not the raw tail); keep the better attempt if the retry breaks more.
5. Re-score the stored diffs with 1-2 (no model run needed), then re-run with the variants:
   `WORKER_BENCH_ATTEMPTS=2 WORKER_BENCH_FORMAT=1 WORKER_BENCH_CHEATSHEETS=1 bench/worker/run.sh gpt-oss:20b`.

Ideas still open: Claude writes the tests first (tests as contract), `--thinking high`, qwen3-coder with a smaller context, OpenVINO on the NPU, a dedicated worker user.

Raw results and diffs: `~/.local/state/worker-bench/`.
