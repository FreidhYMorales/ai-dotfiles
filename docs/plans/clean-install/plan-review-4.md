# Plan review: clean-install
Verdict: PASS WITH CHANGES
Summary: There are no blockers, and all MUST work fits because there is no deadline. Reviews 1 to 3 are resolved in the plan; the sum of 18.6 d is correct, and the follow-ups are findings 1, 5, 6, 7 and 10. Three majors remain: the final format gate skips the `age` archives, the VM gate has no outcome if virgl fails, and nothing secures the historical repos before each `.git` loses `origin`.

Limits: I inspected code and live state read-only and opened no secrets. I did not run bootstrap, a VM or a virgl test, and the external disk was not checked.

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Gaps: format gate | major | The final gate covers the `tar` and directory copies only. The `age` archives (`~/.ssh`, 910 MB of `~/.claude/projects`, optionally opencode) and `worker-bench` are taken in stage 0, then go stale over about 15 dev-days. The decrypt test from review 1 #11 is in no scope row: gap 2 only proves the passphrase can be opened, not that it decrypts these archives. A wrong passphrase would surface only after the wipe. | plan.md:83, :86, :88-89, :99, :113, :130, :179 | Add to row 113: retake the `age` archives and `worker-bench`, then run `age -d \| tar -t` from the disk with the passphrase typed from the phone. |
| 2 | Gaps: VM gate | major | A green VM pass is a precondition for the format, and virgl has a time-boxed smoke test, but no row says what happens if it fails or the box expires. Graphical checks (C1, the fallback, the default bar) depend on it, and the plan names no other proving ground. The reinstall could stall or a failed proof could be waved through ad hoc. | plan.md:4, :15, :17, :112, :209 | Decide the outcome now: a named alternative display setup, or an accepted partial pass (non-graphical checks in the VM, graphical ones at first boot, with the fallback documented). See question 1. |
| 3 | Gaps: migration | major | Stage 3 removes `origin` from each old `.git`, but no step pushes everything to the frozen repo first. Today, `AI` has 2 commits on no remote, including `5b59193`, plus an uncommitted plan and untracked reviews. `NOTCH` has 2 unpushed commits on a story branch, while row 100 says one. `AI` has 25 local branches against 3 remote heads, and those branches' commits are otherwise on remotes. The historical path is unnamed, has no inventory row and is not in the post-format chain, although bench tasks 01-09 depend on it. After the format those tasks skip with no restore step, leaving 11 of 20. | plan.md:53, :72-93, :100, :111; `git log --branches --not --remotes`; `git for-each-ref`; `git ls-remote`; `bench/worker/validate.sh:53-57`; `bench/worker/lib.sh:67-69` | Before the rename: push all refs and require an empty `git log --branches --not --remotes` in all three repos. Name the historical paths, and add an inventory row saying they are re-cloned from `*-history` when the bench resumes. Fix row 100's count. |
| 4 | Gaps: gates | minor | `require-check.trusted=true` is local config in the `AI` clone only, and neither `install.sh` nor `docs/recovery.md` sets it. Re-creating `AI` in stage 3, and cloning after the format, leaves the Stop-hook gate inert, with only a one-line note. "Live" is proven only by the gitleaks commit. | plan.md:55, :105; `git config --local --list` in `AI`; `README.md:17`; `install.sh` | Add the command to the post-install doc for `AI`, decide on `NOTCH`, and add a VM check. |
| 5 | Technical: migration | minor | "Re-created at the same path" is undefined. A re-clone deletes ignored live files on the working machine: `hypr/deadlock/colors.lua`, `hyprpaper.conf`, `matugen/output`, `colors.json`, yazi plugins and zellij themes. Recreating the submodule also swaps the directory the bar runs from after the cutover. Uncommitted work also needs a place to go. | plan.md:103, :111; `git status --ignored` in `SYS`; `SYS/.gitmodules` | Specify `git init` in place, with `.git` swapped and the ignored files kept. For the submodule, stop `qs` and restart it afterwards. Check with `git status --ignored`. |
| 6 | Contradiction | minor | The root is "the pre-cutover tree" and the second commit is the cutover. The cutover lands before stage 2, and stage 2 then edits `SYS`, including `keybinds.lua`. Read literally, the root drops the stage 2 fixes. Any later edit to the two cutover files can also make the tested `git revert` conflict on the real machine. | plan.md:103, :109, :119, :216 | Define the root as the final tree with the cutover reversed. Check that `git diff HEAD~1 HEAD --stat` touches only the cutover files. Repeat the revert test whenever those files change. |
| 7 | Contradiction | minor | Resolution 12 requires closing sessions and disabling timers before the final backup, and review 3 #5 superseded only "sync the delta". Row 113 omits both steps, so memories and transcripts can change after the final backup and archives. | plan.md:113, :180, :219; `AI/docs/recovery.md:20` | Add both to the start of row 113, before the backup and archives. |
| 8 | Gaps: VM | minor | The throwaway restic repo has no stated origin. A copy of real engram puts real memories and the real password in a VM with shared sign-in. The documented `./install.sh` also enables the timers once `engram.env` exists, which conflicts with "timers stay off" unless they are disabled afterwards. "No real keys" (line 123) also reads badly next to real sign-in. | plan.md:112, :123; `AI/install.sh:347-349`; `AI/docs/recovery.md:54-58` | Seed a fresh repo with a throwaway password and one marker memory. Add the disable step to the permitted deviation. |
| 9 | Gaps: publish | minor | Dropping `backup/` fixes references for `post-install.md` only. `SYS/CLAUDE.md` and `dotfiles/README.md` also point to other files there (vision, deploy strategy, matugen pipeline, `caelestia`, `end-4`). Separately, app-written tracked files will keep drifting in a public repo: Vesktop `settings.json`, `btop.conf`, `lazy-lock.json` and `.atl/skill-registry.md`. Review 3 #9 asked whether to untrack them, and the plan never answers. | plan.md:111, :223; `rg "backup/"` in `SYS` (`CLAUDE.md:32,41-47,72,84,92,101-102`; `dotfiles/README.md:68,72`); `git status --short` | Gate on `rg "backup/"` returning no stale pointers. Untrack the Vesktop settings and skill registries, and record a keep-or-untrack decision for the other two. |
| 10 | Gaps: chain | minor | `clean-install-plan` holds the checklist and first-boot stories, but the post-format chain does not clone it. | plan.md:53, :111, :114 | Add it to line 53 and the post-install doc. |
| 11 | Review status | minor | Checked: review 3 #1-#16 and its risks have matching text in the plan, and #17's disk risk is recorded as accepted. Resolved with follow-ups: review 3 #2 (finding 6), #4 (finding 10), #9 (finding 9). Review 1 #11 and #12 regressed from resolution text to rows (findings 1 and 7). Also confirmed: bench tasks 05-09 are the only absolute-source tasks and 10-20 use a fixture or their own source, `AI` and `NOTCH` have no stashes or tags, `~/Mio` holds only `SYS`, and `~/.config/systemd/user` unfolds because two Stow packages share it. | plan.md:163-232; `fd source bench/worker/tasks`; `git stash list`; `SYS/dotfiles/{matugen,systemd}` | None beyond the findings above. |

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| Stage 0 | 0.5 | MUST |
| Vesktop ignores, dirty files, unpushed commits | 0.1 | MUST |
| Notch 19, 27, 28 | 2.25 | MUST |
| Notch 24, 29, 33, 15, webapps (user decision) | 5.25 | MUST |
| Cutover, C1, root and revert structure | 1 | MUST |
| Chain path doc | 0.75 | MUST |
| Packages and "live" proof, including the trust setting | 0.5 | MUST |
| Fresh clone, failure handling, re-runs | 1.25 | MUST |
| Flags and `--no-gpu` advice | 0.25 | MUST |
| Ollama and NPU | 0.25 | MUST |
| Hook removal | 0.25 | MUST |
| Post-install doc | 0.25 | MUST |
| Stage 3 publish: three by-eye tree reviews, licences, migration, bench, plan repo (plan says 2.25) | 3 | MUST |
| Stage 4 VM pass, including the virgl decision | 2.5 | MUST |
| Reinstall checklist, including `age` gate and session close | 0.25 | MUST |
| Reinstall and first-boot checks | 1 | MUST |
| Docs wording cleanup (rank 1: supports demo 1) | 0.25 | SHOULD |
| pi and local worker pieces | 0.25 | LATER |
| CI or repeatable `SYS` test | 1 | LATER |

Total MUST: 19.35 dev-days vs available: open-ended (no deadline, solo) -> fits

## Unnamed risks
- The external disk is plugged in during manual partitioning, and its device name can be confused with the NVMe; this could wipe the only copy — low, catastrophic — Add to the checklist: after `tar --compare`, unplug the disk before partitioning, and check `lsblk` by size and model.
- `quickshell-git` floats (`bootstrap.sh:246`), so a build or Qt mismatch can appear in the 7 days between the green run and the format, leaving first boot with no bar. Review 1 proposed a saved build, and the plan adopted only the 7-day rule — medium — Save the built package and the `pacman -Q` list from the final VM run to the disk.
- `AI/docs/recovery.md:41` installs the latest engram, while stage 0 proves the restore only with the current binary, so a schema change between them is untested — low — Record the version at the final backup and keep that release's binary on the disk.
- Stage 3 changes `AI` while the Claude hooks and plugins run from that working tree (`plugins/toolkit/hooks`), so an agent session can fail mid-migration — low to medium — Do the `AI` swap from a plain terminal with no session open, then re-run `./install.sh`.

## Questions for the user (max 5)
1. If virgl cannot run Hyprland and Quickshell within the time box, what proof do you accept before the format? — A green VM pass gates the wipe, and the graphical checks may be unprovable there. — Recommendation: accept a partial pass, with all non-graphical checks in the VM and graphical ones at first boot. Keep the `git revert` fallback and the ISO redo as the way back.
2. Do you want bench tasks 01-09 available after the reinstall? — They need the historical clones, otherwise they skip and only 11 of 20 tasks remain. — Recommendation: push all refs now, and re-clone `dotfiles-history` and `ai-dotfiles-history` only when the local-worker work resumes.

Technical recommendations I resolved myself: use `git init` in place for the working copies, define the root as the final tree with the cutover reversed, seed the VM's backup repo with a fresh password, and untrack the Vesktop settings and skill registries.

Plan reviewed: /home/deadlock/Documents/MISC/DOTFILES IA/docs/plans/clean-install/plan.md
