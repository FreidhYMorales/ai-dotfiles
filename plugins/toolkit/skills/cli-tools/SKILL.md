---
name: cli-tools
description: "Trigger: writing or suggesting shell commands (for the Bash tool or for the user to run), Bash tool, search files, find files, edit config, JSON/YAML, refactor, benchmarks, legacy-cli hook block. Pick the modern CLI tool for each task and use its flags correctly."
license: Apache-2.0
metadata:
  author: FreidhYMorales
  version: "1.1"
---

## Activation Contract

Load this skill before running shell commands through the Bash tool, before giving the user commands to run, and whenever the `prefer-modern-cli` hook blocks a command.

- Prefer Claude Code's dedicated tools when they fit: Grep (ripgrep-based) for content search, Glob for file names, Read for viewing files, Edit for targeted changes.
- This skill governs what goes inside Bash commands.

## Hard Rules

| Rule | Requirement |
|------|-------------|
| No legacy tools | Do not use `grep`, `egrep`, `fgrep`, `find`, `ls`, `sed` or `cat` (for reading). The hook blocks them. |
| Verify flags | Check `<tool> --help` before writing a flag you are not certain of. |
| Lint scripts | Run `shellcheck` on any hook or shell script before enabling it. |
| Targeted edits | For one change among several identical matches, use the Edit tool, `jq`/`yq`, or `ast-grep`, not `sd`. |
| Escape hatch | Append `# legacy-cli` only when a legacy tool is truly required (e.g. POSIX-only scripts that must run elsewhere), and state why. |

## Decision Table

| Task | Tool | Example |
|------|------|---------|
| Text search | `rg` | `rg -n 'TODO' src/` |
| Find files | `fd` | `fd -e ts config` |
| Read / print a line range | `bat` | `bat -p -r 10:40 f.go` |
| Simple literal replace | `sd` | `sd -F 'oldName' 'newName' f.ts` |
| Structural search / refactor | `ast-grep` | `ast-grep run -p 'console.log($$$A)' -l ts` |
| JSON | `jq` | `jq '.scripts' package.json` |
| YAML / TOML | `yq` | `yq '.services' compose.yml` |
| List dirs / trees | `eza` | `eza -la`, `eza -T -L 2` |
| Shell script lint | `shellcheck` | `shellcheck hook.sh` |
| Code stats | `tokei` | `tokei src/` |
| Benchmarks | `hyperfine` | `hyperfine 'cmd a' 'cmd b'` |
| HTTP requests | `xh` | `xh GET api.example.com/items` |
| Disk usage | `dust` | `dust -d 2` |
| Processes | `procs` | `procs node` |

## Gotchas

- **rg / fd skip hidden and `.gitignore`d files by default.** Use `rg --hidden --no-ignore` (or `rg -uu`) and `fd -HI` when searching config, `.env`, build output or vendored code.
- **fd takes a regex, not a glob.** Use `-g '*.test.ts'` for globs and `-e ts` for extensions.
- **fd has no depth limit unless `-d` is given.** Never add `-d` when the file's location is unknown.
- **bat:** `-p` prints plain (no decorations); `-r A:B` prints lines A to B.
- **sd replaces EVERY match in the file.** `-n N` limits replacements per file, counted from the top, so it cannot pick the third of five matches. Use `-F` for literal strings and `-p` to preview.
- **yq is mikefarah v4** (Go). Edit in place with `yq -i '.a.b = "x"' f.yml`; read TOML with `-p toml`. The Arch package named `yq` is a different (Python, jq-wrapper) tool, so syntax found online may not apply.
- **ast-grep:** `ast-grep run -p 'PATTERN' -l <lang>` searches; add `-r 'REWRITE'` to preview a rewrite and `-U` to apply it. `$VAR` matches one node, `$$$ARGS` matches zero or more.

```bash
# Rename a call while keeping its arguments
ast-grep run -p 'oldFn($$$ARGS)' -r 'newFn($$$ARGS)' -l ts      # preview
ast-grep run -p 'oldFn($$$ARGS)' -r 'newFn($$$ARGS)' -l ts -U   # apply
```

## Escape Hatch

When a legacy tool is genuinely needed, append the marker and explain why in your message:

```bash
sed -i 's/a/b/' portable.sh  # legacy-cli: script must run on POSIX hosts without sd
```
