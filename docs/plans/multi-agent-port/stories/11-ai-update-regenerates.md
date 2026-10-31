# Story 11: ai-update regenerates and relinks the OpenCode and Antigravity outputs

## Story

11. As a developer, I want `ai-update` to regenerate and relink the OpenCode and Antigravity outputs so that they never go stale after a pull. Requires: #08

## Acceptance criteria

- [ ] Given OpenCode or Antigravity is installed and the repo sources changed since the last install, when I run `ai-update` (even when no plugin or engram update is pending), then the generated files are regenerated and relinked, and I am told to restart OpenCode when the build changed.
- [ ] Given the generator fails, when I run `ai-update`, then the previous build stays linked, I see the error and `ai-update` exits non-zero.
- [ ] Given `--check`, or neither OpenCode nor Antigravity is installed, when I run `ai-update`, then the build and its links are left untouched.

## Plan

- `ai-update` finds the repo through its own resolved link, then reuses the installer for the OpenCode and Antigravity targets it detects (never the Claude target), so generation, the atomic swap and relinking keep one implementation.
- The regeneration runs on every non-`--check` run, independent of the plugin/engram plan and without a prompt: it only rebuilds derived files.
- Fingerprint the build before and after; a changed build prints the restart line.
- Cover the three criteria in `scripts/tests/ai-update.test.sh` with a stub repo/installer in the sandbox.

## Out of scope

- Running `git pull` from `ai-update`.
- Installer hardening (`.bak-*` sweeps, `mktemp` hooks write, agy version warning): #22.
- Restarting OpenCode or agy automatically.
- The Claude target and plugin install logic.

## Suggestions (your call)

- Assumption: reusing `install.sh --target <detected>` also re-runs its idempotent common steps (bin links, units, git hooks); acceptable since a re-install is safe, and it avoids a second copy of the swap logic.
- Assumption: the restart line names OpenCode only, as the plan (R6 risks) states.

## Size

normal
Risk: item 5 (ai-update drives the installer and swaps the live build)

## Log

- L1 request: /flow:story 11
