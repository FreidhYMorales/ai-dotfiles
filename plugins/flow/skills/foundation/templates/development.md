# Development setup: <project>

Anyone must be able to go from a fresh clone to a green `make check` with this file alone, on any supported dev OS.

## Supported dev environments

| OS | Status | Notes |
|---|---|---|
| <e.g. Arch Linux> | supported | <maintainer's machine> |
| <e.g. Windows 11> | supported | <Git Bash or WSL for make> |
| <e.g. macOS 14+> | best effort | <untested in CI> |

## Toolchain versions

Pinned in: <`.tool-versions` / `.nvmrc` / `.python-version` / `rust-toolchain.toml`>. Install pinned versions with a version manager that reads the pin (nvm-windows, fnm, mise, uv), not a "latest LTS" package: those drift (e.g. winget's Node LTS installs 24 when 22 is pinned).

Line endings: `.gitattributes` forces LF (`* text=auto eol=lf`). A clone made before it landed: `git add --renormalize . && git checkout -- .`.

| Tool | Version | Why it is needed |
|---|---|---|
| <e.g. Node> | <22.x> | <runtime, build> |
| make | any | `make check` quality gate |

## Install prerequisites

### <Arch Linux>

```bash
sudo pacman -S --needed <packages>
```

### <Debian / Ubuntu>

```bash
sudo apt install <packages>
```

### <macOS>

```bash
brew install <packages>
```

### <Windows>

```powershell
winget install <version manager, e.g. CoreyButler.NVMforWindows> Git.Git ezwinports.make
<e.g. nvm install 22; nvm use 22>  # first time from an elevated terminal
```

<How to get `make` and a POSIX shell: Git Bash + `winget install ezwinports.make`, or WSL.>

## First run

```bash
git clone <repo-url>
cd <project>
cp .env.example .env   # fill in values; never commit .env
<install dependencies, e.g. pnpm install>
make check             # must pass before you change anything
```

## Daily commands

| Task | Command |
|---|---|
| Run the app | <command> |
| Tests | <command> |
| Format | `make fmt` |
| Fast checks (the hook runs them between turns) | `make check-fast` |
| Full quality gate | `make check` |

## Troubleshooting

| Symptom | OS | Fix |
|---|---|---|
| <e.g. `make: command not found`> | Windows | <install make or use WSL> |
