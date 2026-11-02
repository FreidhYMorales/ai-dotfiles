# Story 41: agy rules, skills and agents sentinels on the installed version

## Story

41. As a developer, I want the agy rules and skills sentinels re-run on the installed agy version, plus whether agy discovers a `.bak-*` file in its agents dir, so that the installer links only paths the current agy really reads. Requires: #16

## Acceptance criteria

- [ ] Given a unique sentinel in each candidate rules file and sentinel skills in each candidate skills dir (including a `.bak-*` dir, a same-name clash and `skills-backup/`), when `agy -p` runs twice outside any repo on the installed agy, then `docs/multi-agent.md` shows both tables re-checked on that version, with any changed row marked (manual check).
- [ ] Given a sentinel agent saved as a `.bak-*` file in agy's agents dir, when `agy -p` is asked which subagents it has, then `docs/multi-agent.md` records whether agy discovers it; if it does, a new backlog story covers moving such files out (manual check).
- [ ] Given every re-checked row matches the current tables and the `.bak-*` agent is not discovered, when the installer runs on that agy version, then it prints no version warning, and another version still warns naming the new proven version.

## Plan

- Claude places the sentinels with backups of anything they touch, runs `agy -p` twice plus a control run without sentinels, and removes every sentinel at the end, leaving the dirs as before.
- Results go into the two existing tables and a new agents row in `docs/multi-agent.md`, with the agy version and date; the "checked on 1.4.7" wording and the test comment that says 1.4.9 are brought in line.
- Only when everything matches: the installer's proven version moves to the installed one, test first.
- Any mismatch (a rules file or skills dir read differently, a discovered `.bak-*` agent) is recorded and becomes a new backlog story; the pin is not moved and nothing else is fixed here.

## Out of scope

- Changing which paths the installer links, or sweeping `.bak-*` out of the agents dir (a new story if needed).
- Hooks (#39, #40, #43); subagent engram and registry tools (#42).
- Pinning or upgrading agy itself; the pin only names the version the paths were proven on.

## Suggestions (your call)

- None.

## Size

normal
Risk: item 5, 6 (temporary sentinels in agy's config dirs and the installer's proven-version pin; agy's discovery is only checkable by hand)

## Log

- L1 request: /flow:story 41
- L2 question: bump the installer's pin in this story if the re-run matches? User: "si".
- L3 assumptions for approval: the installed agy is 1.4.12; Claude runs `agy -p` itself (it needs no permission flag); a subagent counts as discovered when `agy -p` lists it or can call it by its sentinel name.
