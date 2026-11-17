# Ideas

Triage log for ideas outside current scope. One row per idea; details below.

| # | Idea | Verdict (GO/DEFER/DROP/SPIKE) | Target (v1/v2/backlog) | Effort (dev-days) | Date | Link |
|---|---|---|---|---|---|---|
| 01 | Replace SDD with a light backlog → story → pair loop | GO | v1 (before multi-agent-port) | 3–5 | 2026-10-26 | [01](#01-replace-sdd-with-a-light-backlog--story--pair-loop) |
| 02 | Split install.test.sh so make check fits the Stop gate comfortably | GO | backlog (multi-agent-port #33) | 0.5 | 2026-10-30 | [02](#02-split-installtestsh-so-make-check-fits-the-stop-gate-comfortably) |
| 03 | Retire openspec/ and the legacy plan lookup | GO | backlog (replace-sdd #11) | 0.5–1 | 2026-11-02 | [03](#03-retire-openspec-and-the-legacy-plan-lookup) |
| 04 | Detect a stale plugin cache (content changed without a version bump) | DROP | - | - | 2026-11-02 | [04](#04-detect-a-stale-plugin-cache-content-changed-without-a-version-bump) |
| 05 | Deny reading credentials, also through Bash | GO | backlog (audit-fixes #02) | 0.5–1 | 2026-11-02 | [05](#05-deny-reading-credentials-also-through-bash) |
| 06 | Harden the require-check Stop gate | GO | backlog (audit-fixes #03) | 1–1.5 | 2026-11-02 | [06](#06-harden-the-require-check-stop-gate) |
| 07 | Close the pi-box escape through .git | GO | backlog (audit-fixes #04) | 0.25–0.5 | 2026-11-02 | [07](#07-close-the-pi-box-escape-through-git) |
| 08 | Make CI trustworthy again (timing-flaky tests, timeout margin) | GO | backlog (audit-fixes #01) | 1–2 | 2026-11-02 | [08](#08-make-ci-trustworthy-again-timing-flaky-tests-timeout-margin) |
| 09 | Warn when the look Claude Code pin is stale | GO | backlog (audit-fixes #08) | 0.25 | 2026-11-02 | [09](#09-warn-when-the-look-claude-code-pin-is-stale) |
| 10 | Rebuild on a fresh machine, proven in a clean container | GO | backlog (audit-fixes #06) | 1–1.5 | 2026-11-02 | [10](#10-rebuild-on-a-fresh-machine-proven-in-a-clean-container) |
| 11 | Behaviour tests for the global gitleaks hook | GO | backlog (audit-fixes #05) | 0.25–0.5 | 2026-11-02 | [11](#11-behaviour-tests-for-the-global-gitleaks-hook) |
| 12 | Uninstall, dangling hooksPath warning, prune old backups | GO | backlog (audit-fixes #09) | 0.5 | 2026-11-02 | [12](#12-uninstall-dangling-hookspath-warning-prune-old-backups) |
| 13 | Settings merge that also removes entries dropped from the fragment | DEFER | backlog (until it bites) | 0.5–1 | 2026-11-02 | [13](#13-settings-merge-that-also-removes-entries-dropped-from-the-fragment) |
| 14 | Offline resilience: cache update-check failures, retry timers | GO | backlog (audit-fixes #11) | 0.25–0.5 | 2026-11-02 | [14](#14-offline-resilience-cache-update-check-failures-retry-timers) |
| 15 | ai-update: prune old copies, full rollback on a failed doctor | GO | backlog (audit-fixes #10) | 0.5–1 | 2026-11-02 | [15](#15-ai-update-prune-old-copies-full-rollback-on-a-failed-doctor) |
| 16 | Repo hygiene: doc drift, mutation list, bench validation, ignores, vendored license | GO | backlog (audit-fixes #12) | 0.25–0.5 | 2026-11-02 | [16](#16-repo-hygiene-doc-drift-mutation-list-bench-validation-ignores-vendored-license) |
| 17 | Recovery drill restores real engram memories | GO | backlog (audit-fixes #07) | 0.5 | 2026-11-02 | [17](#17-recovery-drill-restores-real-engram-memories) |
| 18 | Honest dry-run for prune_links | GO | backlog (audit-fixes #17) | 0.1 | 2026-11-04 | [18](#18-honest-dry-run-for-prune_links) |
| 19 | look agent.list test flakes at the 5 s watchdog | GO | backlog (audit-fixes #18) | 0.1 | 2026-11-04 | [19](#19-look-agentlist-test-flakes-at-the-5-s-watchdog) |
| 20 | Uninstall says so when jq or rg is missing | pending | backlog | 0.1 | 2026-11-04 | [20](#20-uninstall-says-so-when-jq-or-rg-is-missing) |
| 21 | A 30 s budget for every look harness test | GO | backlog (audit-fixes #19) | 0.1 | 2026-11-04 | [21](#21-a-30-s-budget-for-every-look-harness-test) |
| 22 | Real mutation survivors in backup-status and hooks-path | pending | backlog | 0.1 | 2026-11-05 | [22](#22-real-mutation-survivors-in-backup-status-and-hooks-path) |
| 23 | make check leaves the repo alone under an exported GIT_DIR | GO | backlog (audit-fixes #23) | 0.25 | 2026-11-05 | [23](#23-make-check-leaves-the-repo-alone-under-an-exported-git_dir) |
| 24 | Verifier scratch clones cannot push back | GO | backlog (audit-fixes #24) | 0.25 | 2026-11-05 | [24](#24-verifier-scratch-clones-cannot-push-back) |
| 25 | Small gaps in the bench step | GO | backlog (audit-fixes #25) | 0.25 | 2026-11-05 | [25](#25-small-gaps-in-the-bench-step) |
| 26 | A verifier that keeps its shell and a caller that cannot widen it | pending | backlog | 0.5 | 2026-11-05 | [26](#26-a-verifier-that-keeps-its-shell-and-a-caller-that-cannot-widen-it) |
| 27 | What makes make check exceed 300 s with a bench change | SPIKE (absorbed by 28) | backlog | up to 1 h | 2026-11-05 | [27](#27-what-makes-make-check-exceed-300-s-with-a-bench-change) |
| 28 | Tiered checks: a fast hook between turns, the full suite at ship and CI | GO | v1 (before clean-install stage 2) | 1.5–2.5 | 2026-11-12 | [28](#28-tiered-checks-a-fast-hook-between-turns-the-full-suite-at-ship-and-ci) |
| 29 | Retire Antigravity: support only Claude Code and OpenCode | GO | v1 (before the system reinstall) | 1–1.5 | 2026-11-17 | [29](#29-retire-antigravity-support-only-claude-code-and-opencode) |

---

## 01. Replace SDD with a light backlog → story → pair loop

- Idea: Retire the `sdd` plugin (7 phases + OpenSpec) and replace it with a light loop: a backlog of one-line stories, one story refined just in time (acceptance criteria, out of scope), then pair programming in small Strict TDD steps with the test committed before the code. Delegation and verification are sized by understanding, risk and resumability, not by file counts; an independent verifier runs only for high-risk changes.
- Motivation: the current flow is waterfall-like and heavy for solo projects; the upstream it came from (gentle-ai) already dropped SDD; porting SDD is the most expensive part of `multi-agent-port`. The loop must also suit local models.
- Raised during: `/flow:plan-review` of multi-agent-port (review 1)
- Date: 2026-10-26

| Criterion | Assessment |
|---|---|
| Feasibility (technical / data / policy-legal) | High: markdown skills plus installer and test cleanup; no external dependency |
| Complexity | Medium: 3 new skills (backlog, story, pair); `flow:handoff` feeds the backlog instead of SDD; new sizing and verification rules in `claude/CLAUDE.md`; retire `plugins/sdd` (63 files) and its references in `install.sh`, `upstreams.json`, `README.md`, `docs/multi-agent.md`, `scripts/tests/install.test.sh`, `plugins/toolkit/skills/work-unit-commits` |
| Effort (dev-days, range) | 3–5 |
| Value / impact | High: lighter daily flow, fewer tokens, fits local models, removes ~2.5 dev-days (item 5) from multi-agent-port |
| Risk | Medium: losing SDD's verify/archive gates. Mitigation: keep Strict TDD, the `require-check` Stop hook, and an independent verifier for high-risk changes |
| Dependencies | `multi-agent-port` plan is paused and must drop item 5 afterwards |
| Fit (v1 / v2 / backlog) | v1, before multi-agent-port |
| Displaces | multi-agent-port (paused until this lands); its item 5 is removed |

- Research:
  - Gentleman Programming, "Matamos al SDD para siempre" (2026-10-20, https://youtu.be/eGJoDxuILK0): SDD as waterfall; ODD (Organic Driven Development) grows process only when needed.
  - gentle-ai repo: issue #4959 retired SDD/OpenSpec (`odd/tasks/remove-sdd-odd-only-main.md`); task size canon (`odd/tasks/task-size-canon.md`): small = understood within one bounded read, contained risk, resumable from the request and `git diff`; file counts never decide; high-risk list: data/irreversible, security, consumed contracts, concurrency, delivery/environment, no test would catch a regression.
  - HolaMundo, "Me equivoqué, NO uses Spec Driven Development" (2026-10-23, https://youtu.be/5JjuF1zpNbI): backlog of one-line user stories, refine one story just in time into a throwaway plan, pair in small TDD steps, commit each test before the code to catch test tampering, vertical slices, strong model for stories and a fast model for implementation.
  - Local models (`plugins/toolkit/skills/delegate-local/SKILL.md:36-47`, `bench/worker/`): good at L1 (one function) and L3 (find the bug) with a check, weak at 2–3 files and long instructions, and they delete or weaken tests (4 of 13 passing patches). One pair step = one test plus minimal code, which matches L1; stories stay on a strong model.
- Recommendation: GO via `/flow:plan`; tradeoff: pauses multi-agent-port for a few days, but the port then carries a smaller flow already in use.
- Decision: GO — SDD is removed entirely (option A); `openspec/specs/` stays as behavior documentation.
- Next: `/flow:plan` (kept short; this change is the first trial of the lighter approach).

## 02. Split install.test.sh so make check fits the Stop gate comfortably

- Idea: the `require-check` Stop hook reported "make check timed out after 300s" on many turn ends in this repo only; make the gate reliable again.
- Findings (measured 2026-10-30, 8 cores): a lone `make check` takes 131s (non-test steps ~9s; tests run per file in parallel, so the total is the slowest file: `install.test.sh` 118-122s with 47 serial installs, then `engram-backup.test.sh` 51s, `gen-agents.test.sh` 26-29s). The 300s timeouts came from overlap: a background `make check` or install suite started by the assistant was still running when the hook started its own. `timeout 300` leaves no orphan test processes. Other projects are fast because their `make check` takes seconds; the hook runs it on every dirty turn end, so here each `/flow:pair` turn waits about 2 minutes.
- Score: feasibility high; complexity low (move sections into 3-4 files with a shared helper, no assert changes); effort 0.5 d; value high here (make check ~131s → ~55s); risk low (order-dependent sections surface); no dependencies; fits the multi-agent-port backlog as a standalone tooling story; displaces nothing on the cut line, done before #12.
- Recommendation: GO; tradeoff: half a day not spent on #12, for ~75s saved on every turn end. Plus a practice rule: never end a turn while a background `make check` or test suite runs.
- Decision: GO (user, 2026-10-30) → backlog #33.

## 03. Retire openspec/ and the legacy plan lookup

- Idea: delete `openspec/` (5 frozen specs and 2 archived changes; git keeps them) and drop the legacy `openspec/changes/<change>/` lookup from the 9 `flow` skills, their goldens and tests.
- Motivation: the repo should hold only what is used; history lives in git (local and remote). No active plan lives under `openspec/changes/`, so the lookup never finds anything, and no code or current doc reads `openspec/specs/`.
- Revisits: idea 01's "`openspec/specs/` stays as behavior documentation" (replace-sdd plan: frozen history).
- Score: feasibility high (all local); complexity low (one repeated line in 9 skills); effort 0.5–1 d; value medium-low (cleaner tree, one dead step less per skill run); risk items 3 and 6 (skills read by three agents, wording graded only by a paid `make eval`, max ~USD 6); no dependencies; fits the replace-sdd backlog; displaces nothing (no deadline, no open stories).
- Recommendation: GO; tradeoff: the specs leave the tree (still reachable with `git show`) for one paid eval run.
- Decision: GO (user, 2026-11-02) → replace-sdd backlog #11.

## 04. Detect a stale plugin cache (content changed without a version bump)

- Idea: fail `make check` or warn in `update-check` when `~/.claude/plugins/cache/ai-dotfiles/*` lags behind the repo, because plugin content changed without a version bump.
- Raised during: config audit (2026-11-02), finding 1.
- Findings: the cache (flow 0.10.0, toolkit 0.14.0 at 1264f49) is stale, but unused. The `ai-dotfiles` marketplace is a local `directory` source with relative plugin paths, which Claude Code loads in place from the repo (https://code.claude.com/docs/en/plugins/loading.md#in-place-and-copied-plugins). Confirmed live: skills and hooks run from `plugins/*` in the repo.
- Recommendation: DROP; nothing to fix, edits apply at the next session or `/reload-plugins`.
- Decision: DROP (user, 2026-11-02).

## 05. Deny reading credentials, also through Bash

- Idea: add deny rules for `~/.config/restic/**` (engram backup password), `~/.config/gh/**` (GitHub token with push), `~/.git-credentials` and every `.env.*` variant (today only 5 names), and close the Bash path.
- Raised during: config audit (2026-11-02), finding 2.
- Findings (https://code.claude.com/docs/en/permissions.md#read-and-edit): `Read` denies also block file commands Claude Code recognizes in Bash (`cat`, `head`, `tail`, `sed`, `tee`) and redirection targets, but not other programs (`bat` unverified, scripts). Hard enforcement is `sandbox.filesystem.denyRead` (OS-level, Bash and children; https://code.claude.com/docs/en/sandboxing.md); a PreToolUse hook matches text only and is bypassable.
- Score: feasibility high; complexity low (denies) to medium (sandbox or hook); effort 0.5–1 d; value high (push token and backup key); risk low (an extra deny blocks a legitimate read); no dependencies; backlog, first priority; displaces nothing (no active plan or deadline).
- Recommendation: GO; tradeoff: the story picks denies + sandbox `denyRead` vs denies + a path guard hook; the sandbox may break tools that need those files (`gh`, `engram-backup` run by Claude).
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #02.

## 06. Harden the require-check Stop gate

- Idea: close three holes in `plugins/toolkit/hooks/require-check.sh`.
- Raised during: config audit (2026-11-02), findings 3-5; verified in the code.
- Findings: (1) `:16` exits 0 silently when `stop_hook_active` is true, so after one block Claude can stop with `make check` red; the early exit exists to avoid an endless loop, so the fix is to keep not blocking but report the red check with a `systemMessage`. (2) `:53-54` honours the `/flow:pair` red marker while its sha is an ancestor of HEAD, which stays true after the green commit, so a forgotten marker disables the gate for the rest of the branch; require `HEAD == red_sha`. (3) any repo with a dirty tree and a `check` target gets its Makefile run, and even detection (`make -npq`, `:37`) expands `$(shell …)`, so an untrusted clone runs code at the first turn end; add a trust rule (allowlisted roots or a per-repo opt-in).
- Score: feasibility high (one hook with tests); complexity low for 1-2, medium for 3 (trust model); effort 1–1.5 d; value high (the gate behind all agent output); risk medium (too strict nags every turn, too lax reopens the hole; `/flow:pair` depends on the marker); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: with (3), repos outside the trust rule stop being checked automatically.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #03.

## 07. Close the pi-box escape through .git

- Idea: stop a sandboxed worker from planting git config that runs on the host.
- Raised during: config audit (2026-11-02), finding 6; verified in the code.
- Findings: `bin/pi-box:55` binds the whole project read-write, `.git/config` and `.git/hooks` included; `delegate-local` then runs `git status`, `git diff` and `git -C <worker> diff` on the host (`SKILL.md:54,56`), so `core.fsmonitor` or `diff.external` written by the model execute unsandboxed. `scripts/tests/pi-box.test.sh` covers only HOME and parent-dir escapes.
- Score: feasibility high (`--ro-bind "$root/.git"` after `:55`, or `git -c core.fsmonitor= -c diff.external=` in the skill); complexity low; effort 0.25–0.5 d with an escape test; value medium (local workers parked, delegate-local DRAFT, the worker bench also uses pi-box); risk low (unverified: a read-only `.git` breaks pi if it commits); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: if pi commits inside the box, the fix moves to the git side instead of `--ro-bind`.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #04.

## 08. Make CI trustworthy again (timing-flaky tests, timeout margin)

- Idea: get the `check` workflow on main green unless something is really broken.
- Raised during: config audit (2026-11-02), finding 7; verified with `gh run list` / `gh run view --log-failed`.
- Findings: 10 of the last 15 runs on main failed. Three timing-sensitive tests cause it: `plugins/look/tests/look.test.sh` (most runs), `plugins/toolkit/hooks/tests/pack-hint.test.sh` ("two parallel sessions: one hint") and `plugins/toolkit/opencode/tests/toolkit.test.sh` ("the pack hint is cut off at its 2 s timeout (took 4s)"). Tests run in parallel on a 2-core runner; the job takes up to ~9m48s against `timeout-minutes: 10` (`.github/workflows/check.yml:23`). Earlier fix: multi-agent-port #48.
- Score: feasibility high; complexity medium (root cause per test, then load-tolerant timing, a separate look job, or less CI parallelism); effort 1–2 d; value high (red means nothing today); risk low (never inflate timeouts until a test proves nothing); no dependencies; audit-fixes backlog, high priority; displaces nothing.
- Recommendation: GO; tradeoff: 1–2 days on tests instead of features, for a red that means something again.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #01.

## 09. Warn when the look Claude Code pin is stale

- Idea: tell the user at startup when the installed Claude Code differs from the version look is pinned to.
- Raised during: config audit (2026-11-02), finding 8; verified.
- Findings: pin 2.1.305 (`plugins/look/tests/claude-code.version`), installed 2.1.317. The only signal is a WARN inside `look.test.sh`, hidden because `require-check` prints nothing on a green check; CI tests the pinned build, not the one in use. Bump procedure: `docs/look.md:94`. Same pattern exists for agy (`install.sh:468`).
- Score: feasibility high (one note in `update-check.sh`); complexity low; effort 0.25 d with a test; value medium (learn before look silently breaks); risk low (Claude updates often: rate-limit to once a day via the existing cache); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more startup line until the pin is bumped, which forces keeping it current.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #08.

## 10. Rebuild on a fresh machine, proven in a clean container

- Idea: make `docs/recovery.md` + `install.sh` rebuild the whole setup on a clean Arch machine, and prove it with a test in a clean container.
- Raised during: config audit (2026-11-02), findings 9, 13, 14; verified in the code.
- Findings: (1) the pacman line (`docs/recovery.md:26`) misses `make` and `shellcheck` (needed by `make check`, so `require-check` fails here on every dirty turn end), `zellij` (step 5 starts with `cz`), `bubblewrap` and `socat` (`pi-box`) and a Nerd Font (look); `install.sh:95-100` requires only jq, rg and claude. (2) `install.sh` runs with `set -euo pipefail` (`:33`) and calls `systemctl --user daemon-reload` unconditionally (`:296`), so without a user bus (ssh, sudo, container) it dies after linking `bin/`, before the git hooks and the Claude step (inferred from code, not run). (3) `--dry-run` on a fresh machine lists no OpenCode/agy links, because `link_generated` (`:248-255`) walks a build dir that dry-run never builds.
- Score: feasibility high; complexity low for the fixes, medium for the container test; effort 1–1.5 d; value high on the day a disk dies; risk low; no dependencies; audit-fixes backlog; displaces nothing. Interacts with idea 08: run the container test outside the main `check` job (own job, or only when `install.sh`/`docs/recovery.md` change) so it does not eat the timeout margin.
- Recommendation: GO with a container test that follows `recovery.md` step by step, since a hand-kept list drifts again; tradeoff: extra CI time.
- Decision: GO with the container test (user, 2026-11-02) → audit-fixes backlog #06.

## 11. Behaviour tests for the global gitleaks hook

- Idea: test what `git-hooks/_dispatch` does, not only that it is linked.
- Raised during: config audit (2026-11-02), finding 10; verified in the code.
- Findings: the dispatcher blocks a commit on a gitleaks finding (`:11-17`) and chains to the repo's own hook (`:25-28`), for every repo via the global `core.hooksPath`. No test exercises either: `scripts/tests/checks.test.sh:74` stubs it with `echo ok`, `install-claude.test.sh` only checks `hooksPath`. Also, without gitleaks installed it only warns and lets the commit through (`:19`), so a fresh machine (idea 10) loses the protection silently.
- Score: feasibility high (temp repo, fake AWS key, expect exit 1); complexity low; effort 0.25–0.5 d; value high (last barrier before pushing a secret, in every repo); risk low (needs gitleaks in CI, else skip with a visible notice); no dependencies, complements idea 10; audit-fixes backlog; displaces nothing.
- Recommendation: GO: tests for block, chaining and `SKIP_GITLEAKS`. Open for the story: block or warn when gitleaks is missing (safer vs. blocks commits on a half-installed machine).
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #05.

## 12. Uninstall, dangling hooksPath warning, prune old backups

- Idea: a basic `./install.sh --uninstall`, a startup warning when the global `core.hooksPath` points to a missing directory, and pruning of old `*.bak-*` files.
- Raised during: config audit (2026-11-02), finding 11; verified in `install.sh`.
- Findings: the global `core.hooksPath` points into the repo (`install.sh:320`); moving or renaming the repo makes git find no hooks, so gitleaks stops in every repo with no error. `link_file` (`:109`) and `merge_settings` (`:138`) leave `*.bak-*` files nothing cleans up. No uninstall path exists.
- Score: feasibility high; complexity low; effort 0.5 d; value medium (the dangling hooksPath is the real risk; uninstall itself is rare); risk low; no dependencies; audit-fixes backlog, low priority; displaces nothing.
- Recommendation: GO with the cut scope; the merge rework is idea 13.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #09.

## 13. Settings merge that also removes entries dropped from the fragment

- Idea: make `merge_settings` remember what the fragment added last time, so removing a deny (or another entry) from `claude/settings.json` also removes it from `~/.claude/settings.json`, and stop fragment scalars from resetting local changes (`outputStyle`, `statusLine`).
- Raised during: config audit (2026-11-02), finding 12; verified in `install.sh:126-133` (arrays unioned, fragment scalars win). No duplicate hooks today because the fragment has no `hooks` key.
- Score: feasibility high; complexity medium (state of the last applied fragment); effort 0.5–1 d; value low today; risk medium (a removing merge can delete a user entry if its state is wrong); no dependencies.
- Recommendation: DEFER until it bites (first removed deny, or a `hooks` key in the fragment); tradeoff: a deny removed from the fragment must be removed by hand.
- Decision: DEFER (user, 2026-11-02).

## 14. Offline resilience: cache update-check failures, retry timers

- Idea: stop paying a network wait at every offline startup, and retry a timer run that fails because the network is not up yet.
- Raised during: config audit (2026-11-02), findings 15, 17; verified.
- Findings: (1) `plugins/toolkit/hooks/update-check.sh:55-58` writes its cache only when curl succeeds, so offline every new session retries (`--max-time 3`). (2) `Persistent=true` catch-up runs at boot, possibly before the network or the keyring; `systemd/engram-backup.service` has no `Restart=on-failure`, so a failed off-site push waits a day. Already mitigated: `backup-status` warns and the next run pushes what was left (`docs/recovery.md:20`).
- Score: feasibility high; complexity low (cache the failure with a short TTL, e.g. 1 h; `Restart=on-failure` + `RestartSec=10min` capped with `StartLimitBurst`); effort 0.25–0.5 d; value low-medium (nothing is lost, only delayed); risk low (cap retries for permanent failures such as a revoked token); no dependencies; audit-fixes backlog, low priority; displaces nothing.
- Recommendation: GO; tradeoff: a bit more systemd config to maintain.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #11.

## 15. ai-update: prune old copies, full rollback on a failed doctor

- Idea: keep only the last few engram update copies, and roll back binary and database together when the new version fails.
- Raised during: config audit (2026-11-02), finding 16; verified in `bin/ai-update:145-169` and on disk.
- Findings: each engram update leaves `~/.engram-backup-<stamp>/engram.db` and `~/.local/bin/engram-<version>.bak`; never pruned (3 + 3 today, ~28 MB, oldest from engram 1.20.0). A memory deleted on purpose (e.g. a secret saved by mistake) survives in them, outside the gitleaks scan and restic retention. Rollback restores only the binary (`:164`), so a schema migration stays; a failing `engram doctor` (`:169`) only warns.
- Score: feasibility high; complexity low (keep last N, e.g. 2) to medium (database rollback, doctor-triggered rollback); effort 0.5–1 d; value medium (rare, but the only way back when an update breaks the database); risk medium (a wrong database rollback overwrites new memories: confirm first, like major-version updates); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO: keep 2 copies; a failed doctor or a non-starting binary restores binary and database together, with confirmation. Tradeoff: no local way back to very old versions (restic covers that).
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #10.

## 16. Repo hygiene: doc drift, mutation list, bench validation, ignores, vendored license

- Idea: one maintenance story for five small gaps.
- Raised during: config audit (2026-11-02), findings 18, 19; verified.
- Findings: (1) `README.md:17` omits the `delegate-local` toolkit skill. (2) `Makefile:29` `HOOKS` leaves `backup-status` out of `make mutate`, although the README claims mutation testing for the hooks. (3) `bench/worker/validate.sh` is not in `make check`. (4) `.claude/settings.local.json` is ignored only by the unmanaged `~/.config/git/ignore`, not by the repo's `.gitignore`. (5) `packs/vendor/taste-skill/` (MIT, `packs/vendor/README.md:10`) ships without its `LICENSE`, unlike the other vendors, so `ai-pack add web` copies it into projects without the notice MIT requires.
- Score: feasibility high; complexity low ((3) may be slow: run only when `bench/` changes); effort 0.25–0.5 d; value medium-low ((5) legal, (4) avoids leaking local config); risk low; no dependencies ((3) interacts with idea 08's timeout margin); audit-fixes backlog; displaces nothing.
- Recommendation: GO as one maintenance story; tradeoff: half a day on small things.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #12.

## 17. Recovery drill restores real engram memories

- Idea: make the CI recovery drill prove that engram can read what was restored, not just that a SQLite file came back.
- Raised during: config audit (2026-11-02), finding 20; verified.
- Findings: `scripts/recovery-e2e.sh` (CI job `recovery`) installs, backs up, wipes and restores, but the database is a hand-made one-table schema (`:56-57`) checked only with `count(*)` and `integrity_check`; it never opens the restored data with a real `engram` binary. The weekly `--verify` checks restic, not engram. A schema change, WAL or side files would leave the drill green and the restore useless.
- Score: feasibility high (CI fetches a pinned engram release with its checksum, as `ai-update` does; `engram save` real memories; `engram search` them after restore); complexity low-medium; effort 0.5 d; value medium-high (proof that memory survives); risk low (one more pin to keep current; a warning like idea 09 covers it); no dependencies (could join idea 10's container test, kept separate: other job, other question); audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: CI downloads one more external binary and keeps one more pin.
- Decision: GO (user, 2026-11-02) → audit-fixes backlog #07.

## 18. Honest dry-run for prune_links

- Idea: under `--dry-run`, `prune_links` should not print "pruned broken link", since nothing was removed.
- Raised during: audit-fixes story 15 (2026-11-04); `prune_backups` got the same fix there (5d53cc6).
- Findings: `prune_links` in `install.sh` calls `run rm "$dst"` and then always echoes "pruned broken link: <path>", so a dry-run claims a removal it only reported as `[dry-run] rm <path>`.
- Score: feasibility high; complexity low; effort 0.1 d; value medium (dry-run tells the truth, the goal of story 06); risk item 5, contained; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more small story.
- Decision: GO (user, 2026-11-04) → audit-fixes backlog #17.

## 19. look agent.list test flakes at the 5 s watchdog

- Idea: stop the look test "an agent missing from agent.list on two polls in a row is stopped, with no alert" from failing CI at the harness's 5 s watchdog.
- Raised during: audit-fixes story 15 merge (2026-11-04), CI run 41883814401: `(fail) ... [5030.28ms]`, green on rerun; an earlier look flake is in engram (`ci/look-flaky`).
- Findings: the test (`plugins/look/tests/agent.test.tsx:91`) sets no `timeoutMs`, so it keeps the 5 s default; story 01 (L3) found this root cause for look cases without `timeoutMs`, and other polling tests use `{ timeoutMs: 30_000 }`. Locally look passes 74/74 in 1.57 s.
- Score: feasibility high; complexity low; effort 0.1 d; value medium-high (a red CI run means something again); risk low (the longer budget applies to that case only; the test still fails if the logic breaks); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more small story.
- Decision: GO (user, 2026-11-04) → audit-fixes backlog #18.

## 20. Uninstall says so when jq or rg is missing

- Idea: `install.sh --uninstall` should stop, or say what it skipped, when `jq` or `rg` is missing, instead of silently leaving plugins, the marketplace or agy's `toolkit` hooks key in place.
- Raised during: audit-fixes story 16 verifier note 1 (2026-11-04).
- Findings: `main` returns into the uninstall path before `require jq` / `require rg`. Without `rg`, `uninstall_plugins` treats every `rg` failure as "not installed" and skips each plugin and the marketplace; without `jq`, `unmerge_agy_hooks` treats the failed `has("toolkit")` as "no key" and keeps it. The output names neither.
- Score: feasibility high; complexity low (run the uninstall after the same `require` checks); effort 0.1 d; value medium (an uninstall that reports success while leaving plugins behind); risk item 5, contained; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more small story.
- Decision: pending (raised 2026-11-04; user asked to record it).

## 21. A 30 s budget for every look harness test

- Idea: give every look case that runs in the harness the 30 s budget, and fail `make check` when one lacks it, instead of fixing each case after it trips the 5 s watchdog in CI.
- Raised during: audit-fixes story 18 ship (2026-11-04), CI run 41917612081 on 1a5a0f2: `(fail) the 60 s agent.list poll finishes an agent whose notification never came [5033.65ms]`.
- Findings: story 18 gave the budget to one case only, and the next run failed on its neighbour. 24 of the 38 harness declarations in `plugins/look/tests/*.test.tsx` have no budget (agent 7, backup-poll 4, ci-poll 3 plus one in a loop that runs 4 times, dismiss 2, idle 1, ingest 6), and two more cases there do not use the harness; `claude plugin test --help` lists no timeout option, so there is no single place to change it. Story 01 (L3) already saw that "the failing case varies".
- Score: feasibility high; complexity low; effort 0.1 d; value high (main is red from this flake); risk low (a hung case takes up to 30 s to fail instead of 5; the assertions still fail fast, as story 18's mutant showed in 245 ms); no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: a slower failure for a case that really hangs.
- Decision: GO (user, 2026-11-04) → audit-fixes backlog #19.

## 22. Real mutation survivors in backup-status and hooks-path

- Idea: pin the three behaviours `make mutate` shows no test protects in these two hooks, so its report can return to listing equivalent mutants only.
- Raised during: audit-fixes story 20 (2026-11-05), first `make mutate` run on these hooks.
- Findings: (1) `backup-status.sh:33` as `return 1`: a failed backup also adds the false note "no engram backup recorded yet", and no test notices. (2) `hooks-path.sh:7` as `|| hook_off`: `AI_HOOKS_OFF=hooks-path` stops silencing the hook, and `hooks-off.test.sh` has no `hooks-path` case. (3) `hooks-path.sh:10` as `exit 1`: a non-startup session exits 1 instead of 0, and no test pins that exit code. Scores: `backup-status` 18/22, `hooks-path` 9/12, `protect-credentials` 8/8. The other survivors do not count: `backup-status.sh:13` and `:47` and `hooks-path.sh:9` are equivalent, and `hooks-off.test.sh` catches `backup-status.sh:9`, a test `make mutate` does not run for that hook. The six hooks listed earlier were not rerun in story 20.
- Score: feasibility high; complexity low (one test case each); effort 0.1 d; value medium (the hooks behave correctly today; the tests would catch a regression); risk low; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more small story.
- Decision: pending (raised 2026-11-05; agreed in story 20 as the way to record real survivors).

## 23. make check leaves the repo alone under an exported GIT_DIR

- Idea: clear git's local variables for the whole of `make check`, not only for the bench step.
- Raised during: audit-fixes story 22, second verifier (2026-11-05).
- Findings: git reads `GIT_DIR` before `-C`, so tests that build throwaway repos act on the checked repo instead. The verifier reports that `scripts/run-tests.sh` under an exported `GIT_DIR`, on a clone of `main`, added fake backup commits, moved `origin/main`, created branches and failed 12 test files. Story 22 protects `bench/worker/lib.sh` only. A pre-commit hook in a linked worktree exports `GIT_DIR`; nothing in this repo runs `make check` that way today.
- Score: feasibility high (`git rev-parse --local-env-vars` lists the names); complexity low; effort 0.25 d; value high (the damage is to refs and can spread to a remote); risk item 5; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more guard in the gate.
- Decision: GO (user, 2026-11-05) → audit-fixes backlog #23.

## 24. Verifier scratch clones cannot push back

- Idea: have `flow:verifier` experiment only in clones with no route back to the repo, and compare the repo's refs before and after instead of assuming they held.
- Raised during: audit-fixes story 22 (2026-11-05), an incident during the second verifier.
- Findings: at 14:01-14:02 fixture commits were pushed into this repo, moving local `main` to 254b3c2 and creating `story/03-x` (reflog entries `push`). Probable cause, not proven: the verifier ran the suite under an exported `GIT_DIR` in a scratch clone, and a clone of a local repo has `origin` pointing back at it. Its report said the repo was unchanged. It came to light only through a ref count going from 26 to 27. GitHub was never affected; `main` was repaired with the user's OK.
- Score: feasibility high; complexity low (instructions plus a before/after ref comparison in `pair`'s check step); effort 0.25 d; value high (a read-only agent wrote to the real repo); risk item 6 for the agent's wording, since no test here can prove how an agent behaves; depends on nothing, and idea 23 narrows one path to it; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: a little more ceremony per verification.
- Decision: GO (user, 2026-11-05) → audit-fixes backlog #24.

## 25. Small gaps in the bench step

- Idea: fix the four low findings the story 22 verifiers left open.
- Raised during: audit-fixes story 22, first verifier (2026-11-05).
- Findings: (1) `scripts/check-bench.sh` prints "no change under bench/" even when it could not compare, with no `origin/main` or no git, as on a pull request that does change `bench/`. (2) Deleting `bench/worker/validate.sh` makes the step exit 127. (3) If the outer timeout lands in the bench step, the nested `timeout 900` survives for a few seconds, up to one nested check. (4) The README's "so never in CI" holds only while CI checks out with `fetch-depth: 1`.
- Score: feasibility high; complexity low; effort 0.25 d; value low-medium (accurate messages, no damage); risk item 5, contained; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: one more small story.
- Decision: GO (user, 2026-11-05) → audit-fixes backlog #25.

## 26. A verifier that keeps its shell and a caller that cannot widen it

- Idea: find out why the verifier loses its shell inside the evals, so they can grade it again, and limit what `/flow:pair` may tell a verifier to the story ID, the plan folder and the reference paths.
- Raised during: audit-fixes story 24 (2026-11-05).
- Findings: (1) In `verifier-catches-tampered-test` and `verifier-passes-good-story`, failing runs report that the subagent had no shell although its definition lists Bash, and `replace-sdd` story 04 L7 saw the same. Neither case reached its threshold on 2026-11-05 (pass rates 0.67 and 0.33; earlier scores in story 04 L8), and a verifier with no shell cannot exercise the clone rules, so these evals prove nothing about them. Cause not confirmed: the traces were not kept. (2) In stories 22 and 24 the caller's own prompts widened the verifier: they asked for clones and `GIT_DIR` runs, and told it to follow the branch's rules over its installed definition, which said read-only. Its written rule that a caller cannot widen it does not stop this; only the ref comparison outside the agent caught the risk.
- Score: feasibility medium ((1) needs a run with `--keep-temp` to read the traces); complexity low to medium; effort 0.5 d; value medium-high (a working eval is the only way to grade item 6 here); risk item 6; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: GO; tradeoff: paid eval runs while diagnosing, and a narrower prompt gives the verifier less context.
- Decision: pending (raised 2026-11-05; the user asked to record it).

## 27. What makes make check exceed 300 s with a bench change

- Idea: find out why `make check` with a change under `bench/` takes over the 300 s limit of `require-check`, which can report a false red at a stop.
- Raised during: audit-fixes story 25 (2026-11-05).
- Findings: with a bench change, 319 s, 327 s and 5:25; with none, 93 s; validation alone about 135 s and the tests step alone 162 s, measured at load 4-6. About 100 s are unexplained, and whether another run overlapped is not proven.
- Score: feasibility high; complexity low to measure, the fix depends on the result; effort up to 1 h; value medium (only while a bench change is unpushed); no risk to measure, item 5 if the gate changes; no dependencies; audit-fixes backlog; displaces nothing.
- Recommendation: SPIKE. Question: what takes the extra 100 s? Measure `make check` with and without a bench change, per step, in a clean clone with nothing else running. Done when the 100 s are explained or ruled out. Tradeoff: it fixes nothing yet, but avoids speeding up the wrong step.
- Decision: SPIKE (user, 2026-11-05). Absorbed by idea 28 (2026-11-12): the `tiered-checks` plan adds a SHOULD report of the five slowest test files in `make test`, since the hook no longer runs the full suite. That report covers the tests step only, so the bench question stays open.

## 28. Tiered checks: a fast hook between turns, the full suite at ship and CI

- Idea: run each check where it pays. The `require-check` Stop hook runs `make check-fast` when the repo defines it (static checks on changed files only, no tests or bench), and `make check` otherwise. `/flow:pair` runs the story's focused test at red and green and the suite once at the end, never "until green" in a loop. `toolkit:ship` and CI keep the full `make check`. Docs-only changes run no tests. Local workers get the focused test command, and Claude reruns the full test command after applying their diff.
- Raised during: clean-install planning (2026-11-09 research, triaged 2026-11-12). Motivation: the user wants organic development without waiting on large suites between messages, also with local models.
- Findings: the hook runs the full 8-step `make check` at every stop with a changed tree, under `timeout 300` (`plugins/toolkit/hooks/require-check.sh`). Measured 2026-11-12 at load 1.4: `shell` 23 s over every script, `json` 0.46 s, `structure` 0.05 s, `settings` 0.12 s, `skills` 0.36 s, `workflows` 0.1 s; `tests` about 162 s over 58 files (already run in parallel) and `bench` variable (idea 27). Upstream gentle-ai runs a quick check once, sends long suites to a fresh worker or CI, ships no git hooks, and never loops until clean (engram `research/check-tiers`).
- Score: feasibility high (own scripts, no external dependency); complexity medium (hook, `Makefile`, `pair`, `ship` and their tests); effort 1.5–2.5 d including the idea 27 measurement and a parallel test runner; value high (each turn from 93–300 s to under 10 s in `AI`, `NOTCH` and later `SYS`); risk medium: a red suite surfaces later, at `ship` or CI, and the gate is a high-risk item, so a verifier is needed; no dependencies; fit v1, before clean-install stage 2; displaces nothing while that plan is paused.
- Recommendation: GO, with idea 27 as the first story (measure each step). Tradeoff: a broken test can go unnoticed for several turns, until `ship` or CI.
- Decision: GO (user, 2026-11-12). Budget for the hook: about 10 s.
- Plan: `docs/plans/tiered-checks/plan.md`. A repo opts in by defining a `check-fast` target; without it the hook runs `make check`. A `check-fast` timeout (60 s) is reported without blocking; a real failure blocks; when the tree is dirty, a green hook means the fast tier passed on the branch's changes; a clean tree runs nothing. Idea 27 is no longer the first story (only its slow-test report remains), and there is no parallel test runner (`scripts/run-tests.sh` is already parallel).

## 29. Retire Antigravity: support only Claude Code and OpenCode

- Idea: drop Antigravity (agy) support from the repo and keep only Claude Code and OpenCode.
- Raised during: triage of "speed up the install tests" (2026-11-17), after story tiered-checks/10's slowest-files report (`install-agy-skills` 79.5 s, `install-agy` 50.5 s). Motivation: less to maintain; the slow agy install tests go away as a side effect. The original speed-up idea was dropped: since tiered checks the full suite only runs at a story's end and at ship.
- Findings: 29 files outside `docs/plans/` name agy: the hook adapters in `plugins/toolkit/hooks/agy/` and their 3 tests, 26 goldens under `scripts/gen-agents/golden/antigravity`, branches in `install.sh`, `scripts/gen-agents/gen.sh`, `scripts/gen-agents/models.json`, `bin/ai-update`, `README.md`, `docs/multi-agent.md`, and about 12 test files (`install-agy.test.sh` and `install-agy-skills.test.sh` whole). OpenCode shares `gen.sh` and `scripts/tests/install-lib.sh`.
- Score: feasibility high (removal only, no external dependency); complexity medium (OpenCode output must stay byte for byte); effort 1–1.5 d; value medium-high (one target fewer per skill change, the two slowest install tests go); risk medium (installer, item 5; OpenCode regressions caught by its goldens); no dependencies (no open stories); fit now, before the system reinstall; displaces nothing (makes the agy parts of the closed multi-agent-port and tiered-checks plans obsolete).
- Recommendation: GO via `/flow:plan`. Tradeoff: 1–1.5 d, and returning to agy means rebuilding the adapters from git history.
- Decision: GO (user, 2026-11-17). The installer only stops installing agy; it does not remove what is already under `~/.gemini/` (the user is reinstalling the system).
