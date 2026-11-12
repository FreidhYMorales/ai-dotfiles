# Plan: clean-install

- Status: draft, reviews 1 to 6 resolved; next blind review pending
- Deadline: none; the reinstall happens once the VM pass is green and the final copy to the external disk is done
- Mode: solo
- Supersedes: none

**Clean install, as the user defines it:** the user installs a minimal Arch by hand, then runs the dotfiles scripts, which download and configure the rest. The base install (partitions, network, user, boot) stays manual and out of this plan, as on the current machine. Test reinstalls only prove the system and its configuration, with no personal data restored; the data goes back only in the definitive reinstall.

## Platforms

| Target | In v1? | Min version / form factor | Distribution |
|---|---|---|---|
| Lenovo ThinkPad X1 Carbon Gen 13 (Core Ultra 7 258V), Arch Linux | yes | Current Arch at install time; UEFI, GRUB | The system repo's install script, after the manual base install |
| A virtual machine running Arch | yes, test only | Booted with systemd and a login session, no NPU or Arc GPU | Same entry point |

- Out of scope: other distros, other hardware, the old Dell, a container as proof of the whole chain (bootstrap needs systemd and a session).

## Research

Read-only survey of the four projects, 2026-11-05 (engram topic `plan/clean-install-research`). `SYS` is `~/Mio/Configuraciones`; `AI` is this repo; `NOTCH` is `QUICKSHELL NOTCH`; `MODELS` is `MODELOS LOCALES Y NPU`.

- v1: `/home` is on the root partition, so a format wipes it. `~/Documents` holds all these projects except `SYS`.
- v1: `SYS/install.sh` clones without submodules; `SYS/dotfiles/deploy.sh:44` initializes the notch submodule under `set -e`, near the end of bootstrap. `NOTCH` story 14 lists a fresh-clone deploy as still manual.
- v1: nothing in `SYS` clones or runs `AI/install.sh`. `SYS/dotfiles/git/.gitconfig:14` points `core.hooksPath` at this repo's absolute path, so global hooks do not run until it is there.
- v1: bootstrap lacks `restic`, `gitleaks`, `socat`, `bubblewrap`, `shellcheck`, a nerd font `AI/docs/recovery.md` lists, and engram.
- v1: `SYS/install.sh:27-32,76` drops `--no-grub` and `--grub-res`. `SYS/CLAUDE.md:57` advises `--no-gpu` on the ThinkPad, which skips `vulkan-intel`; `SYS/README.md:35-38` says the opposite.
- v1: bootstrap installs `ollama` only; `AI/docs/local-workers.md:14` needs `ollama-vulkan` and `igpu.conf`. `download.conf` is documented nowhere.
- v1: `NOTCH` story 32 verified that the notch locks on a real suspend and lid close, and `NOTCH/docs/development.md:126-130` says to remove the system-sleep hook. Bootstrap still installs it.
- v1: lid close is `suspend-then-hibernate`; bootstrap sets `resume=` only inside its GRUB block and only with an active swap partition (`bootstrap.sh:524,571-594`).
- v1: the AI recovery drill in CI uses a stub `claude` and the claude target only, so it does not prove this chain.
- v1: `dotfiles`, `ai-dotfiles`, `quickshell-notch` and `engram-backup` are all private today (`plan-review-1.md`, finding 9).
- v2: neither shell talks to a model. `NOTCH` has an IPC surface (`qs -c notch ipc call`); the NPU reading exists only in the old bar (`SysInfo.qml`).

## Product vision

- **v1 (deliverable when ready):** after a manual base install, the scripts bring up the system dotfiles, the AI dotfiles and the notch as the default bar, proven once in a VM, with what matters copied to the external disk, and the machine ready for the local models project.
- **v2 (later):** the `MODELS` project itself on the clean machine: downloading and measuring models and the NPU, the assistant, and how it connects to Quickshell.

## Core model

```
external disk: Documents, Pictures, notes, chosen Downloads, Files, encrypted keys
        |
manual base Arch install (user)
        |
SYS install script -> bootstrap.sh -> deploy.sh (Stow + notch submodule)
        |
reboot into SDDM
        |
sign in: claude, gh
        |
clone clean-install-plan, AI, NOTCH dev copy and MODELS -> restore the rest from the disk -> AI install.sh -> engram -> restic restore
        |
ready: notch as default bar, gates and hooks live, Ollama set for the GPU, NPU driver
        |
MODELS: downloads models after the install, research, plan, measurements
```

- A project owns its files; a change is made in the repo that owns the file. From handoff on, this plan and its one backlog and story files live in a private `clean-install-plan` repo at `~/Documents/MISC/clean-install-plan`, except notch stories, which stay in the `NOTCH` backlog. Each story names its repo, and its test command is `make check` there; VM-only behaviour is a manual criterion. Flow runs from that repo through a `docs/plans/clean-install` symlink kept out of git by `.git/info/exclude`, with the pattern `docs/plans/clean-install` and no trailing slash, since a trailing slash does not match a symlink. At handoff, `AI` commits `git rm -r --cached docs/plans/clean-install`, because an exclude does not hide tracked files. Closing commits go to the plan repo as `git -C ~/Documents/MISC/clean-install-plan ...`, since `git add` through the symlink fails. Each `git init` in stage 3 creates a fresh `info/exclude`, so the exclude is re-added right after it, before the first `git add`.
- One writer per repo at a time.
- Events: copy taken, notch cut over in the repo, VM pass green, final copy done, format.

## Foundation

n/a: three existing projects with established conventions, though `SYS` has no gate yet and gets a minimal one in stage 2. `MODELS` gets its own foundation after the reinstall.

## Screens

n/a: no new screens. Notch screens are planned in `NOTCH/docs/plans/notch/plan.md`.

## Data captured / data inventory

The user copies what matters to the external disk and restores it by hand.

| Item | Decision | Note |
|---|---|---|
| `~/Documents`, `~/Pictures`, notes (`~/apuntes.md`, `~/quicknotes.md`) | To the disk as a `tar` archive, which keeps permissions and symlinks whatever the disk's filesystem | Decided by the user; `AI`, `NOTCH` and `MODELS` come back by clone, the archive only covers uncommitted work |
| `~/Downloads` | Dropped, except what the user picks | Decided by the user |
| `~/Files` | Emptied to the disk as the last step; on the new install it is a real folder in `/home`, not a partition, holding the `engram-backup` clone and the music | Decided by the user; `~/Music` and `AI/docs/recovery.md` keep their paths; the rest, including `download-models.sh`, stays on the disk |
| Shell history, browser profiles, VMs, Docker, Steam, Bottles | Dropped | Decided by the user; the browser syncs to the user's account |
| Models and `/var/lib/ollama` | Dropped; downloaded after the install | Decided by the user |
| `~/.ssh` | To the disk encrypted with `age`, or new keys generated | Decided by the user; only GitHub and little else depend on it |
| `~/.gnupg` | Dropped | `gpg --list-secret-keys` lists none, and `.gitconfig` sets no signing key (2026-11-06) |
| `~/.pi/agent` | Dropped | Decided by the user; pi is not in use |
| `~/.config/opencode/opencode.json` and the model-switching script | To the disk, encrypted, only if the ChatGPT trial still runs at the format; otherwise dropped and configured again | Decided by the user |
| Ollama drop-ins | Rebuilt by bootstrap (`igpu.conf`, `download.conf`) | The scope item below writes them |
| `~/.claude/projects` (910 MB) | To the disk in an `age` archive, same passphrase | Decided by the user; transcripts may hold tool output with secrets |
| `~/.local/state/worker-bench` (2.7 MB) | To the disk | Decided by the user; a clone cannot bring it back |
| `secrets.zsh` | Nothing to copy | Does not exist on this machine today |
| Anything not listed | Dropped, including `/var/lib/fprint`, `.local/share/keyrings`, `.config/rclone`, `/var/lib/iwd` | The fingerprint is enrolled again after the install |
| `SYS` uncommitted work | Committed or dropped | Vesktop `sessionData/`, `Crashpad/`, `state.json` go in `.gitignore`, never in a commit |
| Engram database | Restored by `AI/docs/recovery.md` from restic | Off-site repo; verified before the format |
| Restic password, `age` passphrase | On the user's phone, never on the external disk | Access proven from the phone alone: see gap 2 |

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| **Stage 0: protect data.** Install `age`; copy to the disk; keys encrypted with `age`; confirm the restic password, the off-site push and a restore into a temporary `HOME` (clone first, with `ENGRAM_BACKUP_ALLOW_RUNNING=1`); `MODELS` gets git and a private remote; the user changes the old RDP password wherever it was reused | MUST | 0.5 | Nothing that matters can be lost |
| Vesktop session files ignored in `SYS`; remaining uncommitted files decided one by one; unpushed `NOTCH` commits pushed | MUST | 0.1 | No session data in a commit |
| **Stage 1: finish the notch** in its repo: stories 19, 27, 28 | MUST | 0 (done: `e570044`, 27 implemented, `116b9a6`) | The bar the new install boots into |
| Rest of the notch, by the user's decision: 24, 29, 33 (lock redesign and notch SDDM theme), 15, and 37 (webapps view). Stories 38-41 are not required; any merged to `NOTCH` `main` by the pin goes in | MUST | 5.25 | The finished rework |
| Notch is the default bar in `SYS`: the cutover committed there; story 14 C1 checked; the notch is used as the only bar for a while before stage 3; `default/` and the Caelestia-named themes are removed and stay only in `dotfiles-history`; `NOTCH/docs/development.md` says `rollback` needs local backups and that a fresh install has no old bar, its way back being an old-bar checkout from `dotfiles-history` or a redo from the ISO | MUST | 0.75 | First boot shows the notch |
| **Stage 2 starts with a minimal `SYS` gate:** `make check` with `bash -n`, `shellcheck`, `shfmt -d`, a flag-forwarding test and `deploy.sh --dry-run` run with `HOME=$(mktemp -d)` after creating `.local/bin` and `.local/share` there, so the result depends on the repo, not on the developer's home | MUST | 0.25 | Stories can follow strict TDD |
| **Stage 2: connect the chain.** A documented path from `SYS` to `AI`, with prerequisites of the base install and the steps needing a person (sign-in, restore from the disk). It gives the exact clone target of each repo (`~/Documents/MISC/DOTFILES IA`, `QUICKSHELL NOTCH`, `MODELOS LOCALES Y NPU`, `clean-install-plan`), since `.gitconfig` points `core.hooksPath` at an absolute path and git runs no hooks, silently, when it is missing | MUST | 0.75 | One path, top to bottom |
| Bootstrap installs what `AI`, `NOTCH` and engram need, from a reviewed `pacman -Qqe` diff, plus `age`, which the diff cannot show; "live" proven with a commit blocked by a fake secret | MUST | 0.5 | Gates work on day one |
| Fresh clone deploys, with the notch submodule; stow early, after creating `~/.local/bin` and `~/.local/share` and with `KEEP_ZSHRC=yes`; optional groups non-fatal, a failed-step summary and a non-zero exit; `-Sy` becomes `-Syu`; `.qmlls.ini` path fixed; `agy` kept or dropped; re-runs safe and tested once in the VM; after `-Syu`, if `/usr/lib/modules/$(uname -r)` is gone, it asks for a reboot and a re-run; `resume` handled for the default `mkinitcpio` hooks; the resume swap excludes `/dev/zram*` by name, since zram also reports TYPE `partition` and starts before the GRUB step, and any existing `resume=` is removed before the new one is written, in GRUB and `/etc/kernel/cmdline`, with a test in the `SYS` gate; the `sudo` timestamp is kept alive in the background during bootstrap, so long AUR builds cannot stop an unattended run at a password prompt | MUST | 1.35 | The install finishes and says what failed |
| `install.sh` forwards every flag; `--no-gpu` advice corrected for the ThinkPad | MUST | 0.25 | Right drivers, right boot |
| Ollama set for the GPU from install: `ollama-vulkan`, `igpu.conf`, `download.conf`; NPU driver and `render` group checked | MUST | 0.25 | `MODELS` starts ready |
| Notch SDDM theme in `SYS`, from story 33: installed by bootstrap, `Current=` switched from `silent`, `GreeterEnvironment` updated (the `eDP-1=2` scale and the `QML2_IMPORT_PATH` that points at `silent`), access by the SDDM system account to the wallpaper and palette verified, and the vendored `silent` theme, with its stray `metadata.desktop.pacnew`, removed; checked in the VM | MUST | 0.5 | Greeter and lock match the notch |
| System-sleep hook removed from `SYS` and bootstrap, along with `keybinds.lua:194`, the stale logind comment and `SYS/CLAUDE.md:75`; only after story 33 merges and the lock-on-suspend check of story 32 is repeated on the new lock | MUST | 0.25 | Lock on suspend stays correct |
| Post-install doc: key restore, restore from the disk, GRUB, first-boot checks; exact commands for `~/Files` and the `~/Music` link, checking it is not a real folder made by `xdg-user-dirs-update`; the `tar -x` command excluding the cloned repos, and a step for picking their uncommitted work; `git config require-check.trusted true` in `AI` and `NOTCH` after the clones; `pacman -U` of the saved `quickshell-git` if the build fails or the bar does not start; the saved engram binary if a restore fails on the latest; `fprintd-enroll` | MUST | 0.25 | Steps can be followed |
| **Stage 3: publish.** `SYS`, `AI` and `NOTCH`: each current repo is renamed, stays private and is frozen as the historical record; a new public repo with no old history becomes the only active one, and commits use the GitHub `noreply` address. Public repos keep `dotfiles`, `ai-dotfiles` and `quickshell-notch`; the old ones become `*-history`, after the user checks for old clones on other machines. Before any rename: all refs pushed, and `git log --branches --not --remotes` empty in all three repos. Order: `NOTCH`, then `SYS` with the new pin, then `AI`, the last from a plain terminal with no agent session open, followed by `./install.sh`. Each old `.git` moves to `~/Mio/history/<repo>.git` and loses its `origin` before the public repo exists, so no old clone can push private history into it. Each working copy gets `git init` in place, because Stow links point into `SYS` and ignored live files (`colors.lua`, `hyprpaper.conf`, matugen output) must stay; the `info/exclude` symlink pattern is re-added right after each `git init`. The `SYS` submodule is rebuilt, since its `.git` file holds a relative `gitdir` that points at nothing once `SYS/.git` moves: stop `qs`, remove `notch-repo/.git`, and after `git init` run `git submodule add` with the public `quickshell-notch` URL at the same path, check out the pin and commit; checked with `git submodule status` and an anonymous `--recurse-submodules` clone. The pin is a `NOTCH` `main` commit taken after story 33 merges, never a feature branch. The nested `.git/modules` notch copy also loses its `origin`. Checked with `git remote -v`, that module's config, the commit count and `git status --ignored`. `.gitignore` rules, including Vesktop session files, come before the first `git add`, and `git ls-files` is read at the root commit. `SYS/dotfiles/git/.gitconfig` moves to the `noreply` address first. Each tree is reviewed by eye (`PASS`, `USER`, `TOKEN`, `gmail`, `@`, `.conf`, tracked Vesktop settings, licences of fonts, images and vendored code), since `gitleaks` misses plain passwords. Each README names the frozen repo as the record of old commit hashes. Each new repo gets an MIT `LICENSE` for the user's own code, keeps third-party notices, and drops any font or image that cannot be redistributed. A provenance check covers notch code reused from the old bar, per `NOTCH/AGENTS.md:51`, with upstream licences checked by hand; anything copied under an incompatible or unknown licence is rewritten or removed. The two Yazi `gitleaks` findings are read by eye and get a narrow allow rule before the first `git add`; `SKIP_GITLEAKS` is forbidden for root commits. `SYS`: `backup/` is dropped after `post-install.md` moves out, gated on `rg "backup/"` finding no stale pointer; Vesktop settings and skill registries are untracked, while `btop.conf` and `lazy-lock.json` stay tracked as real config; stale `SYS/CLAUDE.md:227` and `README.md:135` fixed. `AI`: bench tasks 05-09 point at the historical `SYS` clone; `self` tasks 01-04 keep their semantics, resolving `BASE` from the historical `AI` clone and skipping when it is absent, with a test; `validate.sh` is run directly once, and `make check` by hand for that commit (idea 27). The public `AI` repo ignores `docs/plans/clean-install` from its root commit; `AI/docs/local-workers.md` says how to re-clone the history repos when the workers resume. The submodule pin checked anonymously; `AI/docs/recovery.md` updated; `engram-backup` stays private. Later fixes get `gitleaks` and a by-eye diff through the first-boot checks | MUST | 3.25 | The clones need no auth |
| **Stage 4: prove it.** One VM pass from the public repos, top to bottom, with libvirt/QEMU, OVMF, GRUB, a swap partition per gap 5, virtio-gpu GL, snapshots, a thin 60 GB disk and the user `deadlock`; real sign-in, sessions revoked afterwards. One permitted deviation: a fresh local restic repo with a throwaway password and one marker memory, not a copy of the real one, and backup timers disabled after `install.sh` enables them, so the VM cannot prune or push the real `engram-backup`. Checks: `make check` in `AI` and `NOTCH` (`make ci` in `NOTCH` on a partial pass, the full check at first boot); exact display layout and scale stay first-boot checks; right after bootstrap, before any app starts, `git status` clean in `SYS` and no untracked files under `dotfiles/scripts/.local`; `~/.local/bin` a real directory; `resume=UUID` and the `mkinitcpio` hook, and after a bootstrap re-run following a reboot, exactly one `resume=` in `/proc/cmdline`, matching the swap partition; one hibernate if cheap; the notch SDDM greeter starts and unlocks; a new commit's address is `noreply`; story 14 C1; a virgl smoke test first, time-boxed. If virgl fails, the pass is partial and accepted: all non-graphical checks in the VM, graphical ones at first boot, with a redo from the ISO as the way back. Fixes are allowed during one pass, then one clean final run from a same-day minimal install; repeated if older than 7 days at the format, or if `SYS` or the pin changed, except docs-only changes | MUST | 2.5 | The whole chain, proven once |
| Reinstall checklist, readable from a second device: exact commands; boot the ISO and connect to Wi-Fi before emptying; save the final VM run's `quickshell-git` package, `pacman -Q` list and the current engram binary to the disk, with `virt-copy-out` or a host share because `ufw` blocks `scp`, tried once in the first pass; close sessions and disable timers before the backup and archives; retake the `age` archives and `worker-bench`, then `age -d \| tar -t` from the disk with the passphrase typed from the phone; final backup exits 0, then `git fetch` shows no difference from `@{u}`; a final new `tar` of `Documents`, `Pictures` and notes passes `tar --compare` from the disk and its listing is read; `rsync -anc` empty for directory copies such as `~/Files`; then empty; unplug the disk before partitioning, and pick the target in `lsblk` by size and model; format | MUST | 0.25 | Safe format |
| The reinstall itself and first-boot checks, including a lid close through hibernate | MUST | 1 | The goal |
| Docs wording cleanup: stale Gemini and gentle-ai mentions, stale paths | SHOULD | 0.25 | Docs match reality |
| pi and the local worker pieces, once in use | LATER | 0.25 | Local workers can resume |
| CI or a repeatable install test for `SYS` | LATER | 1 | The user wants no CI now |

Running MUST total: about 17.95 dev-days, against no deadline. Stage 2 stories are grouped into a few, since most are high risk and need a fresh verifier, so its estimate may grow. Order: stage 0, 1, 2, 3, 4, then the format, then `MODELS`. The notch goes before stage 2 because the cutover rewrites `execs.lua` and `keybinds.lua` in `SYS`. Publishing goes before the VM so the pass uses the real path.

## Demo data

n/a. The VM pass uses a fresh restic repo with one marker memory and a throwaway password. It holds real `claude` and `gh` sign-ins, revoked afterwards, and no copied keys.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| 1. Publish before or after the format | Before the VM pass (option B). A `gitleaks` scan on 2026-11-06 found 0 in `AI`, 0 in `NOTCH` and 4 generic findings in `SYS` history, on variables named `which_keys` and `KEYS` in two Yazi files, which look like keyboard hints; confirmed by eye in stage 3 | user | yes |
| 2. Access that survives the format | 2FA for GitHub and Claude is on the user's phone. The restic password is the generated one in `~/.config/restic/engram.pass`, not one the user recalled; the user saved a copy on the phone on 2026-11-06, and the `age` passphrase goes there too, never on the external disk. Stage 0 repeats the snapshots test typing that copy, and the off-site restore uses it too. Before the format, from the phone alone: open both secrets and log in to GitHub and Claude | user | yes |
| 3. Which notch parity views stay | Webapps (story 37) goes before the format. Screensaver and security come after the reinstall, as the user had planned. Story 25 is out, blocked on Quickshell | user | yes |
| 4. External disk capacity and filesystem | Capacity is enough, per the user. Keys go in `age` archives, so the filesystem cannot affect their permissions | user | yes |
| 5. Base install prerequisites the scripts rely on | The user `deadlock` with `sudo` and wheel, GRUB, a hostname, a network configuration with DHCP and DNS that persists after reboot, a swap partition of at least RAM size for hibernate on lid close, listed in `/etc/fstab` and active at boot, since bootstrap only detects swaps that are already on, and no LUKS: `bootstrap.sh:564` overwrites the kernel line. The user may reinstall several times along the way | user, planner | yes |
| 6. Local restic backups once `~/Files` is emptied | The off-site repo is the regular backup; the local copy stays on the disk | planner | yes |
| 7. What the VM cannot prove: no Arc GPU or NPU | Checked on the real machine after the install | planner | yes |
| 8. Idea 27: `make check` above 300 s with a bench change | Spike runs apart; does not block this plan | planner | yes |
| 9. How `AI` and `NOTCH` go public, and the Gmail address on their commits | Same as `SYS`: new public repos, current ones private and frozen; `noreply` address on new commits. The Gmail stays only in private history | user | yes |
| 10. Whether the historical RDP password was reused elsewhere | A stage 0 task for the user: change it wherever it was reused; it may have been exposed in August | user | yes |
| 11. Space for the local VM: the root partition has 29.7 GB free on 2026-11-06; test installs hold no personal data, but all packages here total 28.8 GiB, including `seclists` at 2.1 GiB, plus the package cache (5 GiB here) and tool data | A thin 60 GB disk, and the first pass measures real use. If it nears the free space, the user removes the libvirt VMs already dropped from the inventory (52 GB), or the VM's disk goes on the external disk | user, planner | yes |

## Deferred to v2

- The `MODELS` project: models, NPU measurements, assistant; its `idea.md` places it after the reinstall.
- Quickshell connection for the assistant: nothing to connect to yet; IPC and notifications are the known options.
- NPU reading in the notch: only the old bar has it; add it if `MODELS` needs it.
- Notch story 25, tray submenus: blocked on Quickshell.
- Notch screensaver and security views: after the reinstall, through a submodule update.
- Notch stories 38-41 (month calendar, notification glow, Light/Dark switch, instant swatches): after the reinstall, through a submodule update; the user works on them in parallel, so any merged to `main` by the pin goes in.
- LUKS: decided once everything is finished, since the user may reinstall several times and rarely leaves home with the laptop. It needs `bootstrap.sh:564` to keep the kernel line, and hibernation on encrypted swap solved.
- CI for `SYS`: one VM pass is enough now.

## Demo priorities

1. A VM goes from a minimal Arch to the notch as default bar and gates live, following only the documented path.
2. A restore brings back engram memories from the off-site backup.
3. On the real machine after the format: keys restored, Ollama configured for the GPU, `/dev/accel` accessible.

## Collaboration

- Mode: solo
- People: n/a
- Frozen contracts: n/a
- Work packages: n/a

## Plan-review resolutions

Findings refer to `plan-review-1.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Inventory omitted data on the root partition | Resolved: Documents, Pictures and notes go to the disk with chosen Downloads; history, browser profiles, VMs, Docker, Steam and Bottles are dropped. The user copies and restores by hand, so no archive with exclusions is needed | user |
| 2 | No way back if the install fails | Rejected: what matters is on the disk and the user can redo the install from the ISO. No image of p5 | user |
| 3 | Fate of `~/Files` contradictory | Resolved: emptied to the disk as the last step; models are downloaded again, so the Modelfiles' paths no longer bind | user |
| 4 | Partitions, swap, encryption undecided | Resolved: the manual base install is the user's. The plan only states the swap prerequisite for hibernate | user |
| 5 | Network config not in `SYS` | Rejected: the user configures the network by hand during the base install, as on this machine. This reverses the planner's first resolution | user |
| 6 | No base-install step | Resolved: stays manual; the docs only list the prerequisites (gap 5). This narrows the planner's first resolution | user |
| 7 | Post-install is SHOULD, but restore steps live there | Key restore, GRUB and first-boot steps become MUST; wording cleanup stays SHOULD | planner |
| 8 | `default/` fallback has no working path on a fresh install | The fallback is a `git revert` of the cutover commit, tested once in the VM, emergency-only because it does not lock on suspend. Commit placement: see review 3 #2. Superseded by review 5 #11: no `git revert` fallback | planner |
| 9 | Publishing understated | Publish before the VM; all four repos were private, and `engram-backup` stays so. The rewrite and the 0.5 d estimate were superseded by review 2 #1 and #2: new public repos, with stage 3 estimated in review 3 #1 | user, planner |
| 10 | "Any VM" is not enough | libvirt/QEMU with virtio-gpu GL, snapshots, a thin 60 GB disk and the user `deadlock`; real sign-in with sessions revoked afterwards | planner |
| 11 | Real restore path unproven | Before the format: off-site restore into a temporary `HOME` with the password typed from the phone; decrypt the key archive using only what survives the wipe; `age` with a passphrase kept on the phone | planner, user |
| 12 | No time set for emptying `~/Files` | Stage 0 only copies. The last checklist steps: close sessions, disable timers, final `engram-backup` and `--verify`, sync the delta, empty, format | planner |
| 13 | Notch MUST unbounded | Estimated and kept as MUST: the user wants the notch finished in the clean install, which accepts the higher total. Of the parity views only webapps stays in; screensaver and security come after the reinstall; story 25 is out | user |
| 14 | Failure handling understated | 1 d: stow early, optional groups non-fatal, a failed-step summary and a non-zero exit; the `agy` decision moves into this item | planner |
| 15 | Package list incomplete | A reviewed list from a `pacman -Qqe` diff. "Live" means the AI clone, a test commit blocked by a fake secret, and `make check` in `AI` and `NOTCH` in the VM | planner |
| 16 | Lock on suspend scattered over three stages | Story 32 L8 verified the notch. What remains is removing the hook, `bootstrap.sh:428-431` and the stale logind comment; recheck on the real machine | planner |
| 17 | Open checks and restores | Story 14 C1 added to the VM and first-boot checks; `.qmlls.ini` path fixed; `AI`, `NOTCH` and `MODELS` come back by clone (superseded by review 2 #5), and `MODELS` gets a private remote | planner |
| 18 | Model rebuild only inferred | Rejected: models are downloaded after the install, by the user's decision | user |

Findings below refer to `plan-review-2.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | RDP password in `SYS` history | A new public `SYS` repo with no old history; the current one is renamed, private and frozen as the record. This replaces the rewrite option. The user changes the password if it was reused | user |
| 2 | History not covered; estimate too low | `SYS` history is no longer published. Estimate back to 1.5 d: the earlier cut to 0.5 d rested on `gitleaks`, which misses plain passwords. Bench tasks 05-09 point at the historical clone's path and skip where it is absent | user, planner |
| 3 | Planning docs would publish personal details | The public `AI` tree leaves out `docs/plans/clean-install`, and the rest of `docs/plans` is reviewed by eye; these files stay in the frozen private repo | user, planner |
| 4 | Stow early breaks `~/.local/bin` and `.zshrc` | Create the `.local` directories first, `KEEP_ZSHRC=yes`, and two VM checks | planner |
| 5 | Repos restored from the disk can lose symlinks and exec bits | Repos come back by clone, as the VM proves; `Documents` goes as a `tar` archive for uncommitted work | planner |
| 6 | Data a clone cannot restore | `~/.claude/projects` and `worker-bench` go to the disk; `secrets.zsh` does not exist today | user |
| 7 | No proof the copy is good before emptying | `rsync -anc` empty against the disk is a checklist gate | planner |
| 8 | Password location stated three ways; access unproven | Restic password and `age` passphrase on the phone, never on the disk; a checklist line proves access from the phone alone | user |
| 9 | LUKS can make the install unbootable | No LUKS for now, a stated prerequisite; decided again at the end (deferred to v2) | user |
| 10 | `age` and `git-filter-repo` invisible to the package diff | Named explicitly in the package row. `git-filter-repo` superseded by review 5 #12: dropped | planner |
| 11 | Where `~/Files` content comes back | A real folder in `/home` with the `engram-backup` clone and the music; the rest stays on the disk | user |
| 12 | `--verify` does not prove GitHub got the backup | Final backup exits 0, then `git fetch` shows no difference from `@{u}` | planner |
| 13 | Restore test needs details | Clone first and `ENGRAM_BACKUP_ALLOW_RUNNING=1`, in the stage 0 row and the checklist | planner |
| 14 | C1 and fallback test unplaced | Both in the stage 4 row and first-boot checks | planner |
| 15 | Items with no owner | `.qmlls.ini`, `keybinds.lua:194`, `SYS/CLAUDE.md:75,227` and `README.md:135` added to their rows | planner |
| 16 | No reboot before sign-in | "Reboot into SDDM" added to the chain | planner |
| 17 | Review 1 status | Informational; follow-ups are covered by this table | planner |
| Risks | Stale VM pass, no hardware test, fixes on public repos, virgl | 7-day rule and `-Syu`; ISO and Wi-Fi check before emptying; `gitleaks` and by-eye diff through first boot; time-boxed virgl smoke test | planner |

Findings below refer to `plan-review-3.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Old clones and repo names | Public repos keep `dotfiles`, `ai-dotfiles`, `quickshell-notch`; the old ones become `dotfiles-history`, `ai-dotfiles-history`, `quickshell-notch-history`. Stage 3 mechanics: creation order, old `.git` moved and its `origin` removed first, working copies re-created in place, checks; the user checks for old clones on other machines before the rename. 2.25 d | user, planner |
| 2 | `git revert` commit would not exist | The new `SYS` root is the pre-cutover tree and the second commit is the cutover | planner |
| 3 | Gmail in the public tree | `.gitconfig` moves to `noreply` before the first public commit; `gmail` and `@` join the by-eye list; a VM check | planner |
| 4 | No home for this plan after stage 3 | A small private `clean-install-plan` repo holding `docs/plans/clean-install`, moved before the rename; the public `AI` ignores that path | planner |
| 5 | `rsync` cannot verify a `tar` | A final new `tar`, `tar --compare` from the disk and its listing; `rsync -anc` for directory copies. Supersedes "sync the delta" for those rows | planner |
| 6 | VM lacks UEFI, GRUB and swap | OVMF, GRUB and a swap partition in the spec; `resume=UUID` and the hook checked | planner |
| 7 | Repeat rule resets the proof | 2.5 d: fixes during one pass, one clean final run, docs-only changes exempt | planner |
| 8 | Bench tasks and `BASE` | `self` semantics kept, `BASE` from the historical clone, skip when absent, a test; `validate.sh` directly once and `make check` by hand | planner |
| 9 | `git status` check can fail for other reasons | Run right after bootstrap, plus a separate check on `dotfiles/scripts/.local` | planner |
| 10 | Base install prerequisites imprecise | `sudo`, wheel and a persistent network added to gap 5 | planner |
| 11 | Re-runs and kernel replacement | Re-runs safe and tested once; a reboot request when the running kernel's modules are gone; 1.25 d | planner |
| 12 | Session transcripts unencrypted | `~/.claude/projects` goes in an `age` archive with the same passphrase | user |
| 13 | `~/Music` link | Exact commands and a check in the post-install doc | planner |
| 14 | RDP password task unplaced | Added to the stage 0 row | planner |
| 15 | Stale resolutions | Review 1 #8, #9 and #17 marked as superseded | planner |
| 16 | No licence in the public repos | MIT for the user's own code in all three; third-party notices kept; any font or image that cannot be redistributed is removed in stage 3 | user |
| 17 | Review status | Informational; follow-ups are covered by this table. Review 2's single-disk risk: accepted by the user, no second copy; `tar --compare` reads the archive back from the disk before the format | user |
| Risks | VM with real `gh` sign-in, `mkinitcpio` defaults, dead hashes, Vesktop in the root commit | Throwaway backup repo and timers off in the VM; hooks checked; a README line on the frozen record; ignore rules before the first `git add` | planner |

Findings below refer to `plan-review-4.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Final gate skips the `age` archives | Retaken at the end, with `age -d \| tar -t` from the disk using the phone's passphrase | planner |
| 2 | No outcome if virgl fails | A partial pass is accepted: non-graphical checks in a local QEMU VM on this machine, graphical ones at first boot. It also serves to debug the chain as it is built | user |
| 3 | Refs not secured before `origin` goes | All refs pushed and an empty `git log --branches --not --remotes` before any rename; historical paths `~/Mio/history/<repo>.git`; 3 d for stage 3 | planner |
| 4 | Trust setting lost on a new clone | `require-check.trusted=true` set in `AI` and `NOTCH`, in the packages row and post-install | planner |
| 5 | "Re-created" undefined | `git init` in place, ignored files kept, `qs` stopped for the submodule, `git status --ignored` | planner |
| 6 | Root would drop stage 2 fixes | The root is the final tree with the cutover reversed; the revert test repeats if those files change | planner |
| 7 | Sessions and timers omitted from the checklist | Added before the backup and archives | planner |
| 8 | Throwaway repo undefined | Fresh repo, throwaway password, one marker memory; timers disabled after `install.sh` | planner |
| 9 | Stale `backup/` pointers; app-written tracked files | `rg "backup/"` gate; Vesktop settings and skill registries untracked; `btop.conf` and `lazy-lock.json` stay as real config | planner |
| 10 | Chain does not clone `clean-install-plan` | Added to the chain | planner |
| 11 | Review status | Informational; follow-ups are covered by this table | planner |
| Question 2 | Bench tasks 01-09 after the reinstall | Not restored by default: `dotfiles-history` and `ai-dotfiles-history` are re-cloned to `~/Mio/history/` when the local workers resume, noted in `AI/docs/local-workers.md`; until then the bench validates 11 of 20 | user |
| Risks | Disk plugged in while partitioning, floating `quickshell-git`, engram version, `AI` swap under a running session | Unplug the disk and check `lsblk`; save the package, `pacman -Q` list and engram binary to the disk; swap `AI` from a plain terminal | planner |

Findings below refer to `plan-review-5.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | `SYS` has no gate; flow from a repo with no code | Minimal `SYS` `make check` first in stage 2, 0.25 d; a private `clean-install-plan` repo from handoff with one backlog, each story naming its repo and test command, reached through an excluded symlink. Supersedes "before the rename" in review 3 #4 | planner |
| 2 | Hook blocks the root commit | Narrow allow rule after the by-eye read; `SKIP_GITLEAKS` forbidden for root commits | planner |
| 3 | `make check` needs Wayland | `make ci` in `NOTCH` on a partial pass, the full check at first boot | planner |
| 4 | Trust setting not in post-install | Moved to the post-install row, after the clones | planner |
| 5 | Nested submodule `origin` | Removed too, and checked | planner |
| 6 | `development.md` gives `rollback` | Updated in the cutover row | planner |
| 7 | Saved artifacts without a procedure | Post-install says when to use each | planner |
| 8 | `Documents` archive unencrypted | Stays a plain `tar`: per the user, those files hold nothing important, and they stay on the disk only until the work is done | user |
| 9 | Plain extract overwrites clones | Exact `tar -x` with exclusions, and a step for uncommitted work | planner |
| 10 | No catch-all | Anything not listed is dropped, with the named items; `fprintd-enroll` in post-install | planner |
| 11 | Provenance of `default/` and Caelestia themes | They leave the public tree and stay only in `dotfiles-history`, since the old configuration ends when the notch is finished. This removes the `git revert` fallback: review 1 #8, review 3 #2, review 4 #6 and review 5 #6 are superseded, and the way back is an old-bar checkout from `dotfiles-history` or a redo from the ISO. The check still covers notch code reused from the old bar | user |
| 12 | Stale items | `git-filter-repo` dropped; `age` installed in stage 0; the `local-workers.md` note added to stage 3 | planner |
| 13 | Review status | Informational; follow-ups are covered by this table | planner |
| Risks | Verifier overhead, `scp` under `ufw`, display layout, `.gitmodules` in the history repo | Grouped stage 2 stories; `virt-copy-out` or a host share; layout at first boot; the README record line also names `quickshell-notch-history` | planner |

Findings below refer to `plan-review-6.md`.

| # | Finding | Resolution | Decided by |
|---|---|---|---|
| 1 | Stage 1 stale against the `NOTCH` backlog | Stories 19, 27, 28 marked done at 0 d; webapps is story 37; stories 38-41 deferred to after the reinstall, any merged by the pin goes in (question 1) | user, planner |
| 2 | A re-run can write the zram UUID as `resume=` | Exclude `/dev/zram*` by name; replace any existing `resume=` in GRUB and `/etc/kernel/cmdline`; a `SYS` gate test; a VM check for exactly one `resume=` after a re-run; +0.1 d | planner |
| 3 | Submodule breaks when `SYS/.git` moves | Explicit steps: stop `qs`, remove `notch-repo/.git`, `git submodule add` of the public repo after `git init`, pin, commit; `git submodule status` and an anonymous recursive clone; +0.25 d | planner |
| 4 | Story 33's `SYS` half has no owner | Story 33 stays MUST (question 2): a new `SYS` row installs the notch SDDM theme, switches `Current=`, updates `GreeterEnvironment`, checks greeter access, removes `silent` and is checked in the VM, +0.5 d; the sleep-hook removal waits for story 33 and a repeated lock-on-suspend check | user, planner |
| 5 | Plan bookkeeping through the symlink | `git rm -r --cached` in `AI` at handoff; `git -C` commits in the plan repo; exclude pattern with no trailing slash, re-added after each `git init` | planner |
| 6 | Chain gives no clone targets | Exact clone target per repo in the chain doc | planner |
| 7 | Gate dry-run depends on the developer's home | Run with `HOME=$(mktemp -d)` and the `.local` directories created | planner |
| 8 | Stale cells, gap order, unmarked resolutions | Row cells fixed, gaps 10 and 11 reordered, review 1 #8 and review 2 #10 marked superseded | planner |
| 9 | Swap need not be active at boot | Gap 5: in `/etc/fstab` and active at boot | planner |
| 10 | Review status | Informational; follow-ups are covered by this table | planner |
| Risks | `sudo` timestamp, pin from an open branch, vendored `silent`, stale `GreeterEnvironment` | `sudo` kept alive during bootstrap; pin only a `NOTCH` `main` commit after story 33 merges; `silent` removed by the SDDM row; `GreeterEnvironment` updated there and the greeter checked in the VM | planner |
