# Story 11: Offline startups and timer retries

## Story

11. As the dotfiles owner, I want offline startups without a network wait and timer runs that retry after boot, so that a bad connection costs nothing. (idea 14)

## Acceptance criteria

- [ ] Given the engram release lookup failed in the last hour, when I start a new session, then no lookup is attempted, so the session pays no network wait; after that hour one is attempted again, and a newer engram version already known from an earlier lookup is still noted in the meantime.
- [ ] Given the backup timer's run fails, for example because the network or the keyring is not up yet after boot, when I do nothing, then it runs again on its own about 10 minutes later, at most 3 more times; if all of them fail, the startup `backup-status` warning still appears and the next day's timer run still happens.
- [ ] Given the upstream-watch timer's run cannot reach a repo, when it finishes, then the news already recorded for that repo is still shown at startup, and the run retries on its own with the same limit as the backup.

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
