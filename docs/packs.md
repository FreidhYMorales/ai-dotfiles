# Opt-in packs

`bin/ai-pack` adds tools to one project at a time. The base install stays lean, and a tool that is not added costs no tokens: its skill is not in the project, so Claude never lists it. The manifest is `packs/packs.json`; the vendored sources are in `packs/vendor/`.

## What v1 has

| Pack | Tools | Suggested when the project root has |
|---|---|---|
| `web` | `playwright` (playwright-cli + skill), `web-design-guidelines`, `taste` (skill `design-taste-frontend`) | `index.html`, or `vite`, `react`, `vue`, `svelte`, `next` or `astro` in `package.json` dependencies |
| `diagrams` | `archify` | never (no detection; add it by hand) |

Detection only drives the startup hint (see below). Nothing is installed without `ai-pack add`.

## Usage

```bash
ai-pack list                       # packs and tools in this project
ai-pack add web                    # a pack, or one tool: ai-pack add archify
ai-pack remove web                 # this project only
ai-pack remove web --purge         # also drop the machine install
ai-pack ignore web                 # stop suggesting web here
ai-pack unignore web
ai-pack add web --cwd ~/code/site  # any command takes --cwd (default: the current directory)
```

The project is the git root of `--cwd` (or the directory itself outside git). After `add`, run `/reload-plugins` or restart Claude; the command says which.

What gets written:

| Where | What |
|---|---|
| `<project>/.claude/skills/<tool>/` | The skill, with its own `.gitignore`, so it never shows in `git status` |
| `<project>/.playwright/` | playwright-cli config (also self-ignoring) |
| `$XDG_STATE_HOME/ai-pack` (default `~/.local/state/ai-pack`) | State: what is active per project, ignores, hint times |
| `$XDG_DATA_HOME/ai-pack/npm` (default `~/.local/share/ai-pack/npm`) | One npm prefix per npm tool and version |
| `$XDG_BIN_HOME` (default `~/.local/bin`) | Link to the tool binary, e.g. `playwright-cli` |

### Reading `ai-pack list`

Packs: `✔` every tool active, `◐` some, `·` none. Tools show one of:

- `✔ (via web) 0.1.22`: active. `-> X available` means the manifest pins a newer version (run `add` to update). `(machine X)` means the machine install is a different version than this project's.
- `· not added`.
- `· adoptable (ai-pack add <tool>)`: the dirs already exist and match the pinned hash (for example a copy made elsewhere); `add` adopts them without rewriting.
- `· missing (ai-pack add <tool>)`: it was added, but a directory is gone.
- `⚠ shadowed by <path>`: a personal or plugin skill with the same name hides the project copy. `add` prints the same warning.

Drift: a dir you edited by hand is left alone by `add` (a warning says so) and kept by `remove`.

## Safety

- **Preflight before any write.** Requirements, hashes, destinations and conflicts are checked first; a failure says `nothing was written`.
- **Rollback.** If `add` fails halfway, everything it created is undone.
- **Your files are safe.** `remove` deletes only files ai-pack wrote and that still match. A changed or extra file keeps the dir and prints `delete <dir> to re-add`.
- **Existing dirs are not overwritten.** `add` refuses a destination that exists and is not an ai-pack copy.
- **No escaping the project.** `add` refuses when `.claude` or `.claude/skills` is a symlink that resolves outside the project; `remove` does not follow symlinked components.
- **`--purge` is conservative.** It refuses (`still used by ...`, nothing removed) while another existing project uses the tool. Projects whose root no longer exists are dropped from the count and shown.
- **Leftovers are listed, not deleted.** Runtime output such as `.playwright/output` is printed as `left in place` for you to delete.
- **Foreign files.** A bin link or npm prefix that ai-pack did not create is never replaced or removed.

## Startup hint

The toolkit hook `pack-hint` (SessionStart on startup) runs `ai-pack hint` and shows one line per suggested pack as a `systemMessage`. It costs no tokens:

```
vite detected: ai-pack add web (ai-pack ignore web)
```

It shows once per project and pack, then again after 30 days. It stays silent when:

- the pack is ignored (`ai-pack ignore`) or any of its tools is already active in the project;
- no detection rule matches the project root (`package.json` and `index.html` at the root only);
- it was shown within 30 days;
- `ai-pack`, `jq`, `flock` or `timeout` is missing, the state is unreadable, or the run is slow.

Opt out with `AI_HOOKS_OFF=pack-hint` (see the README). `PACK_HINT_TIMEOUT` (seconds, default `1.5`) sets how long the hook waits before giving up silently.

## Requirements and Arch notes

```bash
sudo pacman -S nodejs npm chromium
```

`add` checks the manifest requirements first and prints the pacman line for what is missing:

| Tool | Needs |
|---|---|
| `playwright` | node >= 22, npm, chromium |
| `taste` | node >= 22, chromium |
| `archify` | node >= 18 |
| `web-design-guidelines` | nothing |

Verified pair: Chromium 154, node 26, playwright-cli 0.1.22. playwright-cli uses the system `/usr/bin/chromium`, so no browser is downloaded.

- Set `NO_UPDATE_NOTIFIER=1` to stop playwright-cli's daily npm update check.
- Never run `playwright-cli install --skills`: it edits `.gitignore` and downloads about 404 MB into `$XDG_CACHE_HOME/ms-playwright`. The pack already installs the skill.
- The pack config sets `allowUnrestrictedFileAccess` so `file://` pages open. Do not point it at untrusted local files.

## Known limits

- **Transitive npm dependencies are not pinned.** The manifest pins `@playwright/cli` and its integrity hash; its dependencies (`playwright`, `playwright-core`) are integrity-checked by npm at install time but not pinned by us.
- **taste writes outside its dir.** It creates `.taste-skill/` in the project and `~/.taste-skill/history.json`. `.taste-skill/` is outside the tool dir, so `remove` does not list it: delete it by hand. It also searches for images over the network when it runs.
- **`archify examples` lists missing pages.** The 15 rendered showcase pages were trimmed from the vendored copy (11.9 MB); the listed paths do not exist. Render and demo work. Vendor notes: `packs/vendor/README.md`.
- **Moved projects.** State keys on the project path. After moving a project, run `ai-pack add` at the new path; matching dirs are adopted by hash. The old path is dropped as a dead root the next time `--purge` counts users.
- **Start `claude` at the repo root.** Project skills are found from subdirectories (checked), but ai-pack state, `list` and the hint key on the git root.

## Updating pins

Pins live in `packs/packs.json` (versions, integrity, tree hashes). To bump one, follow "Update and re-pin" in `packs/vendor/README.md`: re-vendor from the upstream tag, compare the archive hash, re-apply the archify patch, run `ai-pack hash DIR` and update the manifest. `upstreams.json` records the last reviewed release of each source; `upstream-watch` reports when one moves (for example taste-skill v2.1.3 is newer than the v2.1.2 pinned here).
