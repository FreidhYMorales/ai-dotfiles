# Recovering on a new machine

What you need from the old machine: **the restic backup repo** and **its password** (from your password manager). Everything else comes from this repo. The steps below are what `scripts/recovery-e2e.sh` rehearses on a clean Arch container in CI (`recovery` job).

> The backup repo currently lives at `/home/deadlock/Files/backups/restic-engram`, on the **same disk** as the system. If that disk dies, the backup goes with it. An off-site copy is still on the roadmap.

## 1. Packages

```bash
sudo pacman -S --needed git github-cli jq ripgrep restic sqlite openssl procps-ng
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

Close every Claude Code session first (engram must not be running).

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
