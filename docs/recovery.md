# Recovering on a new machine

What you need from the old machine: **a restic backup repo** (the local backup drive, or the off-site copy on GitHub) and **its password** (from your password manager). Everything else comes from this repo. The steps below are what `scripts/recovery-e2e.sh` rehearses on a clean Arch container in CI (`recovery` job), including a restore from the off-site clone alone.

> The local backup repo lives at `/home/deadlock/Files/backups/restic-engram`, on the **same disk** as the system. The off-site copy (below) is what survives that disk dying.

## Off-site copy (private git repo)

A path in `ENGRAM_BACKUP_REPOS` that is the root of a git clone with a remote is an **off-site git repo**: after each backup, `engram-backup` commits the restic repo (encrypted; only `locks/` is ignored) and pushes it. Setup, once per machine:

```bash
gh repo clone FreidhYMorales/engram-backup ~/Files/backups/restic-engram-git
# add the path to ENGRAM_BACKUP_REPOS in ~/.config/restic/engram.env, e.g.
#   ENGRAM_BACKUP_REPOS="/home/deadlock/Files/backups/restic-engram /home/deadlock/Files/backups/restic-engram-git"
engram-backup --init   # on an empty clone: restic init, .gitignore, commit and push
```

- **Secret scan first.** Before backing up to an off-site repo, the run dumps the database to a private temp dir and runs gitleaks over it (same as `engram-backup --scan`). If it finds anything, or gitleaks is not installed, the local repos are backed up as usual but every off-site repo is skipped and recorded as `blocked: secrets found, see engram-backup --scan`. Run `engram-backup --scan` to see the rule and observation id (never the secret), remove or redact that observation, and the next run pushes again.
- **Push failures** (no network, revoked token, a locked keyring when the timer runs and git cannot read the credentials) mark the run as failed: the startup `backup-status` notice warns, and the local commit is kept and pushed on the next run.
- Unchanged data makes no commit. `--verify` and `--restore` use the clone's working tree like any other restic repo. The git history keeps every pushed pack, so the GitHub repo only grows.

## 1. Packages

```bash
sudo pacman -S --needed git github-cli jq ripgrep restic sqlite openssl procps-ng gitleaks
```

Install Claude Code (native installer) and sign in, then `gh auth login` (the dotfiles repo is private).

## 2. Dotfiles

```bash
mkdir -p ~/Documents/MISC
gh repo clone FreidhYMorales/ai-dotfiles ~/Documents/MISC/"DOTFILES IA"
cd ~/Documents/MISC/"DOTFILES IA" && ./install.sh
```

## 3. engram

Install the engram binary into `~/.local/bin/engram` (latest release from `Gentleman-Programming/engram`, check its `checksums.txt`) and its Claude Code plugin:

```bash
claude plugin marketplace add Gentleman-Programming/engram
claude plugin install engram@engram
```

## 4. Restore the memory

Close every Claude Code session first (engram must not be running). If the local backup drive is gone, restore from the off-site clone: `gh repo clone FreidhYMorales/engram-backup ~/Files/backups/restic-engram-git` and use that path below (keep it in `ENGRAM_BACKUP_REPOS` so later backups push again).

```bash
mkdir -p ~/.config/restic
printf 'ENGRAM_BACKUP_REPOS="%s"\n' "/path/to/restic-engram" > ~/.config/restic/engram.env
install -m 600 /dev/stdin ~/.config/restic/engram.pass   # paste the password, then Ctrl+D
engram-backup --restore    # use --restore --force to replace existing data (kept aside)
engram-backup --verify
./install.sh               # now enables the daily backup and weekly verify timers
```

## 5. Check

Start a session with `cz` and run `/doctor`; the startup notices should stay quiet. `engram search "<something you remember>"` should find old memories.
