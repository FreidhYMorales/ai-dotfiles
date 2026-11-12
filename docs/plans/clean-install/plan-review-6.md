# Plan review: clean-install
Verdict: PASS WITH CHANGES
Summary: No blockers. All MUST work fits, since there is no deadline. Reviews 1 to 5 have matching resolutions in the plan text. Four majors are new. Stage 1 is out of date against the NOTCH backlog. Bootstrap can write a zram UUID as `resume=` on a re-run. Stage 3 never says how the SYS submodule is rebuilt after `.git` moves out. Story #33 has a SYS deployment half that no scope row owns. I inspected files read-only. I ran no bootstrap, VM or virgl test, and did not check the external disk.

## Findings
| # | Category | Severity (blocker/major/minor) | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| 1 | Contradiction: scope vs NOTCH backlog | major | Stage 1 budgets 2.25 d for stories 19, 27 and 28. All three are already done (`e570044` on 2026-11-07, 27 implemented, `116b9a6` on 2026-11-08). The row says webapps "needs a new story", but story #37 already exists. Open stories #38-#41 (calendar month view, notification glow, Light/Dark switch, instant swatches) are in no row and no deferral, yet row 103 calls the work "the finished rework". | plan.md:102-103, :133, :148-149; `NOTCH/docs/plans/notch/backlog.md:31,39-41,52-53,61` | Mark stage 1 as done (0 d). Replace "webapps (needs a new story)" with #37. Place #38-#41 in "Deferred to v2" or in the MUST row (question 1). |
| 2 | Technical: hibernate | major | The bootstrap comment says it excludes zram by keeping only swaps of TYPE "partition". `swapon --show` reports `/dev/zram0` with TYPE `partition` too. Bootstrap starts zram at step 20, before the GRUB step. After a reboot, zram is listed first, so a re-run picks `/dev/zram0`. That device's swap UUID is random on each boot, and the `grep` guard only checks that one UUID, so a second `resume=` is appended and the last one wins. Resume then points at a device that does not exist, and lid close (suspend-then-hibernate) loses the session. The VM check after a first run would pass anyway, because there the fstab swap is listed first. | `SYS/dotfiles/bootstrap.sh:294-302` (`systemctl start systemd-zram-setup@zram0`), `:571-590`; live `swapon --show`: `/dev/zram0 partition 4G` listed before `/dev/nvme0n1p6`; `blkid /dev/zram0` returns a UUID | In the fresh-clone row: exclude `/dev/zram*` by name, and remove any existing `resume=` before writing the new one (GRUB and `/etc/kernel/cmdline`). Add a test to the SYS gate. In stage 4, check `/proc/cmdline` for exactly one `resume=` matching the partition, after the re-run. About 0.1 d. |
| 3 | Technical: stage 3 migration | major | The submodule's `.git` is a file holding a relative `gitdir: ../../../../../.git/modules/...`. Once `SYS/.git` moves to `~/Mio/history/dotfiles.git`, that file points at nothing. After `git init` in place, the first `git add` of `notch-repo` then fails or produces a broken gitlink. Nothing re-attaches the submodule to the new public `quickshell-notch` at the new pin. The plan says only "`qs` stops while the `SYS` submodule changes". | plan.md:113; `SYS/dotfiles/quickshell/.config/quickshell/notch-repo/.git`; `SYS/.gitmodules` | Spell out the steps. Stop `qs` and remove `notch-repo/.git`. After `git init`, run `git submodule add https://github.com/<user>/quickshell-notch.git <path>`, then check out the new pin and commit. Check with `git submodule status` and an anonymous clone with `--recurse-submodules`. About 0.25 d. |
| 4 | Gap: cross-repo ownership | major | Story #33 is in the MUST notch row. Its README says the theme "will be migrated to dotfiles after validation". SYS installs only the vendored `silent` theme and hardcodes `Current=silent` and silent's `QML2_IMPORT_PATH`. No stage 2 row installs the notch SDDM theme, switches the config, or retires `silent`. The README also notes that file access by the SDDM system account is unverified. #33 also rewrites `shell/lock/*`, which story 32's lock-on-suspend proof covers, and row 111 removes the sleep hook based on that proof. | plan.md:103, :111; `NOTCH/sddm/notch/README.md:3-5,22-24`; `NOTCH/scripts/install-sddm-theme.py`; `SYS/system/sddm/sddm.conf.d/deadlock.conf` (`Current=silent`); `SYS/dotfiles/bootstrap.sh:358-380`; NOTCH dirty `shell/lock/Lock.qml`, `LockContent.qml` | Add a SYS row (about 0.5 d) for the notch SDDM theme: install, config switch, greeter access to the wallpaper and palette, and a VM check. Repeat the lock-on-suspend check after #33 merges, before the hook is removed. Or defer #33 (question 2). |
| 5 | Technical: flow mechanics | minor | `/flow:pair` commits story logs and the `[x]` line "by named paths" in the current repo. Through an excluded symlink, `git add docs/plans/clean-install/...` fails ("beyond a symbolic link"). The plan says "closing commits go to the plan repo" but gives no command. Two more traps: `.git/info/exclude` does not hide tracked files, and AI tracks `docs/plans/clean-install/plan.md` and `plan-review-1.md` today. Also, `git init` in stage 3 creates a fresh `info/exclude`, so in SYS and NOTCH the symlink can reach the public root commit. | plan.md:60, :113; `plugins/flow/skills/pair/SKILL.md:21,48,65`; `git ls-files docs/plans/clean-install` in AI (2 files) | At handoff, commit `git rm -r --cached docs/plans/clean-install` in AI. Write bookkeeping commits as `git -C ~/Documents/MISC/clean-install-plan ...`. Use the pattern `docs/plans/clean-install` with no trailing slash, since a trailing slash does not match a symlink. Re-add the exclude right after each `git init`, before the first `git add`. |
| 6 | Gap: chain | minor | `.gitconfig` fixes `core.hooksPath` to `/home/deadlock/Documents/MISC/DOTFILES IA/git-hooks`. `gh repo clone` of the public `ai-dotfiles` creates `./ai-dotfiles`, and with a missing hooks path git runs no hooks, silently. The chain does not give clone target paths. | plan.md:53, :106; `SYS/dotfiles/git/.gitconfig:14`; `AI/docs/recovery.md` | In the chain doc, give the exact clone target for each repo (`DOTFILES IA`, `QUICKSHELL NOTCH`, `MODELOS LOCALES Y NPU`, `clean-install-plan`). The fake-secret commit check then catches any drift. |
| 7 | Technical: SYS gate | minor | `deploy.sh --dry-run` runs `stow --simulate` against `TARGET="$HOME"`. The gate's result then depends on the state of the developer's home, not on the repo. | plan.md:105; `SYS/dotfiles/deploy.sh:10-11,50-53` | Run it in the gate with `HOME=$(mktemp -d)`, after creating `.local/bin` and `.local/share` there. |
| 8 | Contradiction: stale text | minor | Row 104 has no Demo value, and its value "First boot shows the notch" slid into row 105 as a fifth cell. Gap 11 is listed before gap 10. The resolution for review 2 #10 still names `git-filter-repo`, and the one for review 1 #8 still names the `git revert` fallback. Both are superseded by review 5 #11 and #12 but not marked. | plan.md:104-105, :140-141, :179, :202 | Fix the cells, reorder the gaps, and add "superseded" to both resolutions. |
| 9 | Gap: base prerequisites | minor | Gap 5 asks for a swap partition but not that it is active at boot. Bootstrap only detects swaps that are already on. | plan.md:135; `bootstrap.sh:571` | Add "in `/etc/fstab` and active" to gap 5. |
| 10 | Review status | minor | Checked: review 5 #1-#12 and its risks have matching plan text (lines 60, 105, 112-115, 91, 104, 269). The MUST sum of 19.35 is correct for the rows as written. Review 4's findings stay resolved. | plan.md:255-272 | None beyond the findings above. |

## Scope vs deadline
| Item | Est. dev-days | Cut (MUST/SHOULD/LATER) |
|---|---|---|
| Stage 0, including `age` | 0.5 | MUST |
| Vesktop ignores, dirty files, unpushed commits (NOTCH now has 29 dirty files on `feat/33` and an unpushed merge) | 0.1 | MUST |
| Notch 19, 27, 28 (done) | 0 | MUST |
| Notch 24, 29, 33, 15, 37 | 5.25 | MUST |
| #33 SYS half: SDDM theme deploy, lock recheck (finding 4) | 0.5 | MUST |
| Cutover, C1, removal of `default/`, docs | 0.75 | MUST |
| Minimal SYS gate | 0.25 | MUST |
| Chain path doc, with clone targets | 0.75 | MUST |
| Packages and "live" proof | 0.5 | MUST |
| Fresh clone, failure handling, re-runs, zram `resume` fix | 1.35 | MUST |
| Flags and `--no-gpu` advice | 0.25 | MUST |
| Ollama and NPU | 0.25 | MUST |
| Sleep-hook removal | 0.25 | MUST |
| Post-install doc | 0.25 | MUST |
| Stage 3 publish, with the submodule steps | 3.25 | MUST |
| Stage 4 VM pass | 2.5 | MUST |
| Reinstall checklist | 0.25 | MUST |
| Reinstall and first-boot checks | 1 | MUST |
| Notch #38-#41 (if the user keeps them out) | 0 here | LATER |
| Docs wording cleanup (rank 1: supports demo 1) | 0.25 | SHOULD |
| pi and local worker pieces | 0.25 | LATER |
| CI or repeatable SYS test | 1 | LATER |

Total MUST: 17.95 dev-days vs available: open-ended (no deadline, solo) -> fits

## Unnamed risks
- Bootstrap calls `sudo -v` once at the start. Long AUR builds (`quickshell-git`, yay) can outlast the sudo timestamp, so a run left unattended stops at a password prompt. That reads as a hang, not as a failed step in the summary — medium — Keep the timestamp alive in the background during bootstrap, or document that the run must be watched.
- Story #33 is in progress on `feat/33-sddm-visual-foundation`, with 29 dirty files including `shell/lock/*`. Cutting over or pinning SYS while that branch is open can pin a lock still under rework — medium — Pin only a `main` commit, and pin after #33 merges or is deferred.
- The `silent` SDDM theme is vendored third-party code in `SYS/system/sddm/themes/silent` and would ship in the public root. That includes a stray `metadata.desktop.pacnew` — low to medium — Name it in the stage 3 licence check, or drop it if the notch theme replaces it.
- `GreeterEnvironment` hardcodes `eDP-1=2` and silent's import path. If #33 changes the theme, a stale path breaks the greeter on first boot — low — Update both with finding 4, and check the greeter in the VM.

## Questions for the user (max 5)
1. Do notch stories #38-#41 (month calendar, notification glow, Light/Dark switch, instant swatches) need to land before the format? — The plan calls the notch "finished", but these four are open and unplaced. — Recommendation: defer them to after the reinstall through a submodule update, like screensaver and security.
2. Must the #33 lock redesign, with its SDDM theme moving into SYS, land before the format? — It reopens the lock-on-suspend proof that the hook removal depends on, and it adds SYS work the plan does not count. — Recommendation: yes if you want the notch greeter on day one, with finding 4's row and a lock recheck. Otherwise defer it and keep `silent` for now.

Technical recommendations I resolved myself:
- Filter zram by name and replace `resume=` instead of appending.
- Rebuild the submodule with `git submodule add` after `git init`.
- Untrack the plan files in AI and re-add the exclude after each `git init`.
- Make bookkeeping commits with `git -C` in the plan repo.
- Give exact clone targets in the chain doc.
- Make the SYS gate's dry-run hermetic with a temporary `HOME`.

Files: /home/deadlock/Documents/MISC/DOTFILES IA/docs/plans/clean-install/plan.md, /home/deadlock/Mio/Configuraciones/dotfiles/bootstrap.sh, /home/deadlock/Mio/Configuraciones/dotfiles/deploy.sh, /home/deadlock/Documents/MISC/QUICKSHELL NOTCH/docs/plans/notch/backlog.md, /home/deadlock/Documents/MISC/QUICKSHELL NOTCH/sddm/notch/README.md
