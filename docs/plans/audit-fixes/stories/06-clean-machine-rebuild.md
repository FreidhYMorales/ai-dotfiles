# Story 06: rebuild on a clean machine, proven in a container

## Story

06. As the dotfiles owner, I want `docs/recovery.md` plus `install.sh` proven on a clean Arch container, with every dependency listed, no abort without a user bus and an honest dry-run, so that I can rebuild the setup when a disk dies. (idea 10)

## Acceptance criteria

- [ ] Given a clean Arch container with only the packages that `docs/recovery.md` step 1 lists, when the CI recovery drill runs, then every tool the setup needs (`make check`'s tools, `cz`'s zellij, pi-box's bwrap and socat) is on `PATH`, and a package dropped from the doc makes the drill fail naming the missing tool.
- [ ] Given a machine with no systemd user bus (container, ssh, sudo), when I run `./install.sh`, then it still installs the git hooks and the Claude step, finishes with "done", and tells me the timers were not enabled and how to enable them later.
- [ ] Given a fresh machine with no build of the generated agents, when I run `./install.sh --dry-run`, then it lists the OpenCode and Antigravity links it would create, and afterwards nothing new exists in my home or in the repo.

## Plan

- The recovery doc's package line gains the missing packages (make, shellcheck, zellij, bubblewrap, socat, a Nerd Font); the drill installs the packages by reading that line from the doc instead of keeping its own copy, so the two cannot drift.
- The drill checks the needed commands after the install and drops its `systemctl` stub, so the real no-bus case is exercised in the container.
- The unit step treats a missing user bus as "not now": skip daemon-reload and enabling, print the hint, carry on.
- Dry-run generates the agents into a throwaway place it removes afterwards, so the listed links are the real ones and no state is left behind.
- Assumptions: `install.sh` keeps requiring only what it needs to install (jq, rg, claude) and warns, without failing, about missing tools other parts use (zellij, bwrap, socat, make, shellcheck); the font is listed in the doc only, not checked; the drill keeps stubbing `claude` and engram stays a SQLite stand-in (real engram is #07); the drill stays in its own CI job, outside `check`'s timeout (idea 08).

## Out of scope

- A real Claude Code or engram install in the container (#07 covers real engram).
- `--uninstall`, the dangling hooksPath warning and backup pruning (#09).
- Offline startup behaviour and timer retries (#11).
- Running `make check` inside the container.
- Changing the README beyond what recovery.md says (#12).

## Suggestions (your call)

- Mark the package line in `docs/recovery.md` with a stable anchor (the only `pacman -S` line in step 1 today) so the drill's extraction fails loudly if the doc's shape changes, instead of silently installing nothing.

## Size

normal
Risk: item 5 (install script and CI recovery job)

## Log

- L1 request: /flow:story 06
