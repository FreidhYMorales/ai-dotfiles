# Story 11: Offline startups and timer retries

## Story

11. As the dotfiles owner, I want offline startups without a network wait and timer runs that retry after boot, so that a bad connection costs nothing. (idea 14)

## Acceptance criteria

- [x] Given the engram release lookup failed in the last hour, when I start a new session, then no lookup is attempted, so the session pays no network wait; after that hour one is attempted again, and a newer engram version already known from an earlier lookup is still noted in the meantime.
- [x] Given the backup timer's run fails, for example because the network or the keyring is not up yet after boot, when I do nothing, then it runs again on its own about 10 minutes later, at most 3 more times; if all of them fail, the startup `backup-status` warning still appears and the next day's timer run still happens.
- [x] Given the upstream-watch timer's run cannot reach a repo, when it finishes, then the news already recorded for that repo is still shown at startup, and the run retries on its own with the same limit as the backup.

## Plan

- Hook: remember a failed lookup for an hour, apart from the last known version, so a failure never erases that version.
- Backup unit: retry on failure with a capped number of attempts; each attempt keeps recording its outcome for `backup-status`, as today.
- upstream-watch: an unreachable repo keeps its previous entry in the state instead of losing it, and a refresh with an unreachable repo reports failure, so its unit can retry with the same cap.
- Prove the cap against a real systemd user manager where one exists; tests that run without a bus pin the unit settings.
- Docs: the README and `docs/recovery.md` lines that describe when a failed run is retried. A machine picks up the new unit settings with `./install.sh`.

## Out of scope

- `engram-backup-verify`: it reads the local repos and the clone's working tree, so a bad connection does not fail it, and a failed verify is a real problem to look at, not to retry.
- Waiting for the network before a run (`network-online.target` belongs to the system manager; a user unit cannot rely on it).
- Telling permanent failures (revoked token, secrets found) apart from temporary ones: the cap bounds them.
- The other startup hooks: `update-check` is the only one that touches the network.

## Suggestions (your call)

- none

## Size

normal
Risk: item 4, 5 (retries of timer runs; systemd unit config)

## Log

- L1 request: /flow:story 11
- L2 assumption: upstream-watch is in scope though idea 14 names only the backup: the backlog line says "timer runs", and L3 shows it loses news.
- L3 signal: `upstream-watch --refresh` rewrites its state even when every repo fails and exits 0. On 2026-11-03, 04 and 05 the boot run took about 1 s (15 s on 2026-11-02) and on 2026-11-05 it left `changed: []`, while a direct check the same day found 7 of 13 upstreams with news. The offline cause is inferred from those timings, not logged.
- L4 assumption: the numbers come from idea 14: 1 h for the failed lookup, 10 minutes between retries. The limit of 3 retries is this story's reading of "capped".
- L5 verifier 1: NEEDS DECISION. Finding 1: the 2 h start-limit window may not count suspended time, so after a failed morning and under 2 h awake the next timer run could be refused (from the verifier's memory of systemd's source, not run). Finding 2: report mode exited 1 with no repo reached and no news, reproduced on the branch and on `main`.
- L6 user decision: the suspend edge is accepted for now, to be solved later; the unit comments and `docs/recovery.md` now state it. Finding 2 fixed before closing.
- L7 verifier 2: FAIL on one sentence only: `docs/recovery.md` gave the wrong trigger for the suspend edge. All criteria, reds, commit order and assertions passed. Correction batch: that sentence reworded, and an empty state file now counts as empty (its non-blocking note, within approved test 9).
- L8 verifier 3, scoped to `1323840..HEAD`: PASS. Non-blocking, left as they are: the unit comments keep the looser "after a long suspend"; the limit may count every start in the window, not only failed ones; a state file of concatenated JSON values is still not repaired.
- L9 commits (test → fix): 1b5f660 → 6082a2f, 6b199d4 → 1cacfce, 71e8595 → 5496416 (update-check); 782d065 → 8d1f450, 95cba82 → 2c52b87, cdb83ba → e6d9cae, 424415a → cf82bae, 45cb250 → 397fc82, 80d5c11 → cae5a3c (upstream-watch); bfebce9 → 01980ad (units). Green on arrival, mutants killed on scratch copies: fbd2024, 50e836b, bd505de. bd505de was committed with shellcheck red, repaired by 0373c12 with no assertion changed. One mutant survived and is equivalent: "the known version always wins" in update-check.
- L10 tests: `make check` "All checks passed (7 steps)". `timer-retries.test.sh` ran against this machine's real user manager, not skipped (CI may skip it): 4 runs, `start-limit-hit`, a start after the window runs again. That start stands in for the timer; no real timer or suspend was exercised.
- L11 pending on each machine: `./install.sh` to load the new unit settings, and `claude plugin update toolkit@ai-dotfiles` for the hook.
- L12 Risk: item 4, 5 (retries of timer runs; systemd unit config)
