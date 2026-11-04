# Story 13: Tell a missing user bus from a real daemon-reload failure

## Story

13. As the dotfiles owner, I want `install.sh` to tell a missing user bus apart from a real `systemctl --user daemon-reload` failure and show the error, so that a broken unit is never reported as "no systemd user session". (story 06 verifier note)

## Acceptance criteria

- [ ] Given `systemctl --user daemon-reload` fails for a reason other than a missing user bus, when I run `./install.sh`, then the output shows systemd's own error and says the timers were not enabled, does not say "no systemd user session", and the install still finishes with "done".
- [ ] Given no systemd user bus (ssh, sudo, container), when I run `./install.sh`, then I still get the "no systemd user session" hint and the install finishes with "done", as today.

## Plan

- Keep the reload's error text instead of discarding it.
- Treat systemd's "Failed to connect" bus error as the missing-bus case, with today's hint; any other failure prints a warning carrying the error.
- In both cases skip enabling the timers and carry on with the rest of the install.
- Cover the real-failure case with a stub `systemctl` in the install tests; the no-bus case is already pinned by the fresh-machine test and the recovery drill, which must stay green unchanged.

## Out of scope

- A failing `systemctl --user enable --now`: it stops the install today with its own error visible, so it is never misreported; that behaviour stays.
- The `--uninstall` path, which has the same blur (see Suggestions).
- Validating unit files.

## Suggestions (your call)

- Assumption: a real failure warns and carries on, exit 0, rather than aborting. The git hooks (gitleaks) install after this step, so aborting here would leave them out. If you prefer a non-zero exit, criterion 1 changes.
- Assumption: the bus case is recognised by systemd's text, as seen on this machine (`Failed to connect to user scope bus via local transport: No such file or directory`, exit 1) and in the fresh-machine stub. There is no separate exit code to use. A systemd that words it differently would show as a real failure, with its error visible.
- Signal: `--uninstall` (story 16) has the same blur: a failed disable prints `skip: could not disable <timer> (no systemd user session?)` with stderr hidden, and its reload failure is swallowed. Widening this story to cover it is one more criterion; say so if you want it.

## Size

normal
Risk: item 5 (install script)

## Log

- L1 request: /flow:story 13
- L2 approved (user, 2026-11-04) as written: a real failure warns and carries on with exit 0; the `--uninstall` blur stays out of scope.
- L3 test list approved (3 cases in `install-fresh.test.sh`), mode C; case 3 is a guard no criterion asks for: capturing the reload's stderr must not lose the dry-run line.
- L4 commits: 6b449bf test (red: "FAIL it shows the error from systemd", "FAIL it does not blame the user session") → b61d153 fix; 17f18fb test (both bus wordings: green on arrival, killed two mutants: every failure treated as real, only `user scope bus` recognised); 7d03b19 test (dry-run line: green on arrival, killed a mutant capturing stdout too).
- L5 evidence: `install-fresh.test.sh` "All cases passed"; `make check` "All checks passed (7 steps)"; tamper check empty.
- L6 verifier: PASS (7d03b19), with one note outside the criteria: the `bus` half of the pattern is not pinned (no test uses a non-bus "Failed to connect" message; a mutant dropping it would likely survive; reasoned, not run).
- L7 Risk: item 5 (install script).
