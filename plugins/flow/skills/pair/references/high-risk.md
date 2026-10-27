# High-risk items and size

The single home of the high-risk list. `flow:story`, `flow:pair`, `flow:verifier` and `claude/CLAUDE.md` point here; never copy the list elsewhere.

## The six items

A story is high risk when its change touches any of these:

1. **Data or irreversible effects**: deletes, overwrites or migrates existing persisted data, or does something that cannot be undone (sends, pays, publishes). Adding a new record is not this item. Example: a migration that drops a column; "delete my account".
2. **Security**: authentication, authorization, secrets, input that reaches a shell, query or file path. Example: changing how passwords are hashed.
3. **Contracts others consume**: an API, file format, CLI flag, event or schema that other code or people parse. Example: renaming a JSON field a client reads.
4. **Concurrency**: shared state, locks, queues, retries, ordering or parallel runs. Example: two workers claiming the same job.
5. **Delivery or environment**: build, CI, deploy, install scripts, runtime config, dependency changes. Example: bumping a runtime version in CI.
6. **No test would catch a regression**: the behaviour cannot be pinned by a test you can run here. Example: a prompt wording change graded only by a paid eval.

**Unclear** counts as high only when a bounded look (the story, the code it touches, one read) cannot tell whether items 1-5 apply. Record it as the item you could not rule out.

## Size

- **small**: understood within one bounded read, the risk is contained, and the work is resumable from the request plus `git diff` alone.
- **normal**: anything else.
- File counts never decide size. Any high-risk item makes a story not small.

## The `Risk:` line

One line, in the story's `## Size` and in pair's closing summary:

```
Risk: item N (reason)        # one item
Risk: item 1, 2 (reason)     # several items
Risk: none
```

The reason is a few words naming what is at risk, e.g. `Risk: item 2 (password reset tokens)`.

## Security sub-checklist (item 2)

Condensed from the sdd threat matrix. For each boundary the story touches, name the safe behaviour, the failure behaviour and one RED test; mark the rest N/A with a reason, and add no tests for N/A rows.

- **Identity**: who may do this; unauthenticated and wrong-user requests are refused.
- **Secrets**: never logged, committed or echoed; read from config or env.
- **Input reaching an interpreter**: shell, SQL, paths, templates; quoted or parameterized, `../` and absolute paths rejected.
- **Repository and process automation**: commands run against the intended repo, branch and ref only (`git -C`, explicit refspecs, `--head`).
- **File classification**: executable look-alikes (`README.sh`, executable Markdown) are not treated as docs.
