---
name: next
description: "Trigger: what's next, what can I do now, finished my part, waiting on teammates, blocked, /flow:next. List tasks the user can start now without waiting for delegated work."
license: MIT
metadata:
  author: FreidhYMorales
  version: "1.0"
---

## Activation Contract

Load when the user finished their own tasks early, is waiting on teammates' packages, or asks what to do next on a planned project. Works for solo projects too (next ready task).

## Hard Rules

- Never pick up a task owned by a teammate. Reassigning it requires explicit user approval AND telling the teammate (avoid duplicate work).
- A task is READY only if every dependency is `integrated`, or it can proceed against a frozen contract with a stub/mock.
- Never change frozen contracts to unblock yourself; if a contract is wrong, stop and raise it with the user.
- Talk to the user in their language.

## Execution Steps

1. If `<plan-dir>/tasks.md` exists, use it (written by `/flow:split`) with the plan's cut line, and follow the steps below. Otherwise read `<plan-dir>/backlog.md` (solo projects): a story is Ready when it is `[ ]` and every `Requires: #N` is `[x]`; `[~]` is in progress. Recommend the lowest Ready ID with `/flow:story NN` (or `/flow:pair NN` if its story file is approved), list the rest as Blocked with what they wait for, then under **Pending evals** every `[x]` story whose story file `## Log` holds `make eval pending (needs Claude)` (a skill story closed outside Claude) and no later Log line with its `make eval` result, each with `make eval PLUGIN=<plugin>` to run in Claude, and stop there. Neither file: offer `/flow:backlog`.
2. Refresh statuses: check the repo/PRs for delivered packages (`gh pr list`, branches, files) and ask the user only about what cannot be verified.
3. Classify every task not yet done:

   | Class | Meaning |
   |---|---|
   | Ready | All dependencies integrated |
   | Ready with stub | Depends on a delegated package but can proceed against its frozen contract with a stub/mock |
   | Blocked | Needs real output from unfinished work |
   | Teammate-owned | Not available unless reassigned |

4. Recommend the next task(s) for the user in this order: own Ready tasks on the critical path → Ready-with-stub own tasks → pull-backlog tasks (unassigned SHOULD, then LATER) independent of delegated work → integration prep (CI, fixtures, `/flow:integrate` checklists for incoming packages).
5. For a Ready-with-stub task, name the stub to create and the integration step to run when the real package arrives.
6. Update `tasks.md` (owner/status) and save a short engram note (type `decision`, topic `next/<feature>`) when the user takes a task.

## Output Contract

- Table of the top 3–5 recommended tasks: task, class, dev-days, why now, what it unblocks.
- Blocked list with what each is waiting for.
- Pending evals (backlog mode): closed stories still waiting for `make eval` in Claude.
- Updated `tasks.md`.
