# Story 16: Basic uninstall

## Story

16. As the dotfiles owner, I want a basic `install.sh --uninstall` that removes only what the installer put in place, so that I can take the setup off a machine cleanly. (idea 12, from #09)

## Acceptance criteria

- [ ] Given a machine the installer set up, when I run `./install.sh --uninstall`, then every symlink it made into this repo or the build dir is gone, its systemd timers are disabled, the global `core.hooksPath` is unset if it points at this repo's `git-hooks`, its Claude plugins and the `ai-dotfiles` marketplace are removed, the `toolkit` key is gone from agy's `hooks.json`, and each removal is named in the output.
- [ ] Given things the installer did not put there (links pointing elsewhere, real files and dirs, a `core.hooksPath` set to another dir, other keys in `hooks.json`, `*.bak-*` copies, `skills-backup/`, `~/.claude/settings.json`), when I run `./install.sh --uninstall`, then they are left untouched, and the output says `settings.json` keeps the merged entries and must be cleaned by hand.
- [ ] Given the same machine, when I run `./install.sh --uninstall --dry-run`, then it names each removal it would make and changes nothing.

## Plan

- One new flag that runs an uninstall path instead of the install, honouring `--target` the same way the install does (common parts always).
- Reuse the installer's own "is this ours" rule (a symlink whose target is inside the repo or the build dir) for every link dir the install writes to.
- Undo the non-link steps the install makes: disable its timers and reload, unset `core.hooksPath` only when it is ours, uninstall its plugins and marketplace, drop only the `toolkit` key from agy's `hooks.json`.
- Go through the existing dry-run wrapper so `--dry-run` reports instead of changing.
- Cover the three criteria with a throwaway HOME and stubbed `claude`/`systemctl`, in a new install test file.

## Out of scope

- Reverting the `settings.json` merge (arrays were unioned; the installer cannot tell its entries from the user's; idea 13 is deferred).
- Restoring any `*.bak-*` copy or the moved-aside `GEMINI.md.bak-*`, or moving anything back out of `skills-backup/`.
- Deleting the generated `build/agents` dir inside the repo, or the repo's own `git-hooks/*` dispatch links.
- Removing engram, its config, restic config or `engram.env`.
- A confirmation prompt.

## Suggestions (your call)

- Assumption: "what the installer put in place" means only the reversible steps above; the settings merge is reported, not undone.
- Assumption: plugins and the marketplace are removed (the install adds them); if you would rather keep them, criterion 1 drops that clause.
- Assumption: no backups are restored, so a file the install replaced stays as `<name>.bak-<stamp>` next to where it was; the output does not list them.
- `prune_links` already encodes the "ours" rule but only for broken links; the uninstall needs the same test without the "broken" condition.

## Size

normal
Risk: item 1, 5 (removes links, config and plugins; install script)

## Log

- L1 request: /flow:story 16
- L2 approved (user, 2026-11-04) by running `/flow:pair 16`, with the assumptions as written (plugins and marketplace removed, settings.json reported only).
