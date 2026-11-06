# Plan: clean-install

- Status: draft, review 1 gaps resolved; second review pending
- Deadline: none; the reinstall happens once the VM pass is green and the final copy to the external disk is done
- Mode: solo
- Supersedes: none

**Clean install, as the user defines it:** the user installs a minimal Arch by hand, then runs the dotfiles scripts, which download and configure the rest. The base install (partitions, network, user, boot) stays manual and out of this plan, as on the current machine.

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
sign in: claude, gh
        |
restore from the disk -> AI install.sh -> engram -> restic restore
        |
ready: notch as default bar, gates and hooks live, Ollama set for the GPU, NPU driver
        |
MODELS: downloads models after the install, research, plan, measurements
```

- A project owns its files; a change is made in the repo that owns the file. This plan lives in `AI` and coordinates; each repo keeps its own backlog and gate.
- One writer per repo at a time.
- Events: copy taken, notch cut over in the repo, VM pass green, final copy done, format.

## Foundation

n/a: three existing projects with established conventions. `MODELS` gets its own foundation after the reinstall.

## Screens

n/a: no new screens. Notch screens are planned in `NOTCH/docs/plans/notch/plan.md`.

## Data captured / data inventory

The user copies what matters to the external disk and restores it by hand.

| Item | Decision | Note |
|---|---|---|
| `~/Documents`, `~/Pictures`, notes (`~/apuntes.md`, `~/quicknotes.md`) | To the disk | Decided by the user; includes `AI`, `NOTCH` and `MODELS` with their git state |
| `~/Downloads` | Dropped, except what the user picks | Decided by the user |
| `~/Files` | Emptied to the disk as the last step | Decided by the user; includes local restic copies and `download-models.sh` |
| Shell history, browser profiles, VMs, Docker, Steam, Bottles | Dropped | Decided by the user; the browser syncs to the user's account |
| Models and `/var/lib/ollama` | Dropped; downloaded after the install | Decided by the user |
| `~/.ssh` | To the disk encrypted with `age`, or new keys generated | Decided by the user; only GitHub and little else depend on it |
| `~/.gnupg` | Dropped | `gpg --list-secret-keys` lists none, and `.gitconfig` sets no signing key (2026-11-06) |
| `~/.pi/agent` | Dropped | Decided by the user; pi is not in use |
| `~/.config/opencode/opencode.json` and the model-switching script | To the disk, encrypted, only if the ChatGPT trial still runs at the format; otherwise dropped and configured again | Decided by the user |
| Ollama drop-ins | Rebuilt by bootstrap (`igpu.conf`, `download.conf`) | The scope item below writes them |
| `SYS` uncommitted work | Committed or dropped | Vesktop `sessionData/`, `Crashpad/`, `state.json` go in `.gitignore`, never in a commit |
| Engram database | Restored by `AI/docs/recovery.md` from restic | Off-site repo; verified before the format |
| Restic password | Password manager | The user confirms access (open question) |

## Scope

| Item | Priority (MUST/SHOULD/LATER) | Est. dev-days | Demo value |
|---|---|---|---|
| **Stage 0: protect data.** Copy to the disk; keys encrypted with `age`; confirm the restic password, the off-site push and a restore into a temporary `HOME`; `MODELS` gets git and a private remote | MUST | 0.25 | Nothing that matters can be lost |
| Vesktop session files ignored in `SYS`; remaining uncommitted files decided one by one; unpushed `NOTCH` commit pushed | MUST | 0.1 | No session data in a commit |
| **Stage 1: finish the notch** in its repo: stories 19, 27, 28 | MUST | 2.25 | The bar the new install boots into |
| Rest of the notch, by the user's decision: 24, 29, 33, 15, and the webapps view (needs a new story) | MUST | 5.25 | The finished rework |
| Notch is the default bar in `SYS`: the cutover committed there; story 14 C1 checked; `git revert` fallback documented | MUST | 0.75 | First boot shows the notch |
| **Stage 2: connect the chain.** A documented path from `SYS` to `AI`, with prerequisites of the base install and the steps needing a person (sign-in, restore from the disk) | MUST | 0.75 | One path, top to bottom |
| Bootstrap installs what `AI`, `NOTCH` and engram need, from a reviewed `pacman -Qqe` diff; "live" proven with a commit blocked by a fake secret | MUST | 0.5 | Gates work on day one |
| Fresh clone deploys, with the notch submodule; stow early, optional groups non-fatal, a failed-step summary and a non-zero exit; `agy` kept or dropped | MUST | 1 | The install finishes and says what failed |
| `install.sh` forwards every flag; `--no-gpu` advice corrected for the ThinkPad | MUST | 0.25 | Right drivers, right boot |
| Ollama set for the GPU from install: `ollama-vulkan`, `igpu.conf`, `download.conf`; NPU driver and `render` group checked | MUST | 0.25 | `MODELS` starts ready |
| System-sleep hook removed from `SYS` and bootstrap | MUST | 0.25 | Lock on suspend stays correct |
| Post-install doc: key restore, restore from the disk, GRUB, first-boot checks | MUST | 0.25 | Steps can be followed |
| **Stage 3: publish** `SYS`, `AI`, `NOTCH`: `gitleaks` on new commits, the 4 `SYS` findings classified, tracked personal data and stale claims reviewed, the submodule pin checked anonymously, `AI/docs/recovery.md` updated, visibility flipped; `engram-backup` stays private | MUST | 0.5 | The clones need no auth |
| **Stage 4: prove it.** One VM pass from the public repos, top to bottom, with libvirt/QEMU, virtio-gpu GL, snapshots, a 120 GB disk and the user `deadlock`; real sign-in, sessions revoked afterwards; `make check` in `AI` and `NOTCH` | MUST | 1.5 | The whole chain, proven once |
| Reinstall checklist, readable from a second device | MUST | 0.25 | Safe format |
| The reinstall itself and first-boot checks, including a lid close through hibernate | MUST | 1 | The goal |
| Docs wording cleanup: stale Gemini and gentle-ai mentions, stale paths | SHOULD | 0.25 | Docs match reality |
| pi and the local worker pieces, once in use | LATER | 0.25 | Local workers can resume |
| CI or a repeatable install test for `SYS` | LATER | 1 | The user wants no CI now |

Running MUST total: about 15.1 dev-days, against no deadline. Order: stage 0, 1, 2, 3, 4, then the format, then `MODELS`. The notch goes before stage 2 because the cutover rewrites `execs.lua` and `keybinds.lua` in `SYS`. Publishing goes before the VM so the pass uses the real path.

## Demo data

n/a. The VM pass uses a throwaway restic copy of engram and no real keys.

## Data gaps & assumptions

| Gap | Assumption | Owner | Resolved? |
|---|---|---|---|
| 1. Publish before or after the format | Before the VM pass (option B). A `gitleaks` scan on 2026-11-06 found 0 in `AI`, 0 in `NOTCH` and 4 generic findings in `SYS` history, on variables named `which_keys` and `KEYS` in two Yazi files, which look like keyboard hints; confirmed by eye in stage 3 | user | yes |
| 2. Access that survives the format | 2FA for GitHub and Claude is on the user's phone. The restic password is the generated one in `~/.config/restic/engram.pass`, not one the user recalled; the user saved a copy elsewhere on 2026-11-06. Stage 0 repeats the snapshots test typing that copy, and the off-site restore uses it too | user | yes |
| 3. Which notch parity views stay | Webapps goes before the format. Screensaver and security come after the reinstall, as the user had planned. Story 25 is out, blocked on Quickshell | user | yes |
| 4. External disk capacity and filesystem | Capacity is enough, per the user. Keys go in `age` archives, so the filesystem cannot affect their permissions | user | yes |
| 5. Base install prerequisites the scripts rely on | The user `deadlock`, GRUB, a hostname, network, and a swap partition of at least RAM size for hibernate on lid close | planner | yes |
| 6. Local restic backups once `~/Files` is emptied | The off-site repo is the regular backup; the local copy stays on the disk | planner | yes |
| 7. What the VM cannot prove: no Arc GPU or NPU | Checked on the real machine after the install | planner | yes |
| 8. Idea 27: `make check` above 300 s with a bench change | Spike runs apart; does not block this plan | planner | yes |

## Deferred to v2

- The `MODELS` project: models, NPU measurements, assistant; its `idea.md` places it after the reinstall.
- Quickshell connection for the assistant: nothing to connect to yet; IPC and notifications are the known options.
- NPU reading in the notch: only the old bar has it; add it if `MODELS` needs it.
- Notch story 25, tray submenus: blocked on Quickshell.
- Notch screensaver and security views: after the reinstall, through a submodule update.
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
| 8 | `default/` fallback has no working path on a fresh install | The fallback is a documented `git revert` of the cutover commit, tested once in the VM, emergency-only because it does not lock on suspend | planner |
| 9 | Publishing understated | Publish before the VM. Visibility known: all four private, `engram-backup` stays so. An earlier audit removed the leaked key from `SYS` history, and a new scan supports a smaller estimate: 0.5 d for new commits, the 4 findings, personal data, the pin check and the flip. A rewrite, if a finding needs one, comes before the flip and updates the pin | user, planner |
| 10 | "Any VM" is not enough | libvirt/QEMU with virtio-gpu GL, snapshots, a 120 GB disk and the user `deadlock`; real sign-in with sessions revoked afterwards | planner |
| 11 | Real restore path unproven | Before the format: off-site restore into a temporary `HOME` with the password typed from the manager; decrypt the key archive using only what survives the wipe; `age` with a passphrase kept in the password manager | planner |
| 12 | No time set for emptying `~/Files` | Stage 0 only copies. The last checklist steps: close sessions, disable timers, final `engram-backup` and `--verify`, sync the delta, empty, format | planner |
| 13 | Notch MUST unbounded | Estimated and kept as MUST: the user wants the notch finished in the clean install, which accepts the higher total. Of the parity views only webapps stays in; screensaver and security come after the reinstall; story 25 is out | user |
| 14 | Failure handling understated | 1 d: stow early, optional groups non-fatal, a failed-step summary and a non-zero exit; the `agy` decision moves into this item | planner |
| 15 | Package list incomplete | A reviewed list from a `pacman -Qqe` diff. "Live" means the AI clone, a test commit blocked by a fake secret, and `make check` in `AI` and `NOTCH` in the VM | planner |
| 16 | Lock on suspend scattered over three stages | Story 32 L8 verified the notch. What remains is removing the hook, `bootstrap.sh:428-431` and the stale logind comment; recheck on the real machine | planner |
| 17 | Open checks and restores | Story 14 C1 added to the VM and first-boot checks; `.qmlls.ini` path fixed; `AI`, `NOTCH` and `MODELS` come back with the Documents restore, and `MODELS` gets a private remote | planner |
| 18 | Model rebuild only inferred | Rejected: models are downloaded after the install, by the user's decision | user |
