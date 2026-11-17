#!/usr/bin/env bash
# Structural test for the flow:pair skill: asserts the contract strings the
# red marker hook, the stop rules and the merge flow depend on.
# Run: bash scripts/tests/flow-pair.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/plugins/flow/skills/pair/SKILL.md"
TDD="$ROOT/plugins/flow/skills/pair/references/strict-tdd.md"
WUC="$ROOT/plugins/toolkit/skills/work-unit-commits/SKILL.md"
failures=0

assert() {
  local label=$1
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$label"
  else
    printf 'FAIL  %s\n' "$label"
    failures=$((failures + 1))
  fi
}

# has FILE TEXT: FILE exists and contains TEXT literally.
has() { [[ -f $1 ]] && grep -qF -- "$2" "$1"; }

# has_re FILE ERE: FILE exists and matches the extended regex.
has_re() { [[ -f $1 ]] && grep -qE -- "$2" "$1"; }

# frontmatter FILE: print the YAML block between the leading --- fences.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit 1; next } $0 == "---" { exit } { print }' "$1" 2>/dev/null
}

echo "== files =="
assert 'skill exists' test -f "$SKILL"
assert 'strict-tdd reference exists' test -f "$TDD"

echo "== frontmatter =="
yaml=$(frontmatter "$SKILL")
assert 'name is pair' grep -qx 'name: pair' <<<"$yaml"
assert 'slash-only (disable-model-invocation: true)' grep -qx 'disable-model-invocation: true' <<<"$yaml"
assert 'description starts with the explicit-use line' \
  grep -qE '^description: "?Explicit use only: /flow:pair NN\.' <<<"$yaml"
assert 'description excludes planning and backlog work' grep -qF 'Not for planning or backlog work' <<<"$yaml"

echo "== red marker and branch =="
for s in 'git rev-parse --git-path flow-pair-red' 'story/NN-' 'git merge --no-ff' \
  'Risk:' 'flow:verifier' 'no runnable test'; do
  assert "skill documents \"$s\"" has "$SKILL" "$s"
done
assert 'mode B requires Risk: none' has_re "$SKILL" 'Mode B.*Risk: none'
assert 'forbids --no-verify' has_re "$SKILL" '[Nn]ever.*--no-verify'
assert 'forbids git add -A' has_re "$SKILL" '[Nn]ever.*git add -A'
assert 'documents the tamper check on test files' has_re "$SKILL" 'git diff <test-commit>'

echo "== stop rules =="
for s in 'design decision' 'unrequested' 'existing test' 'two failed attempts' \
  '50 lines' 'hook rejects'; do
  assert "stop rule \"$s\"" has "$SKILL" "$s"
done

echo "== verifier report =="
# shellcheck disable=SC2016 # literal markdown backticks
assert 'an empty or missing verifier report is NEEDS DECISION, never PASS' \
  has_re "$SKILL" 'empty.*no `Verdict:` line.*NEEDS DECISION, never PASS'
# shellcheck disable=SC2016 # literal markdown backticks
assert 'an empty or missing verifier report leaves the story open' \
  has_re "$SKILL" 'no `Verdict:` line.*the story stays open'

echo "== skill story eval in Claude =="
# Regression pin (story 29): only the generated flow-pair may close a skill
# story with the eval pending; in Claude the make eval result is recorded.
# shellcheck disable=SC2016 # literal markdown backticks
assert 'Claude pair records the make eval result' has "$SKILL" 'for skill stories the `make eval` result'
assert 'Claude pair has no eval-pending line' test -f "$SKILL" -a -z "$(grep -F 'make eval pending' "$SKILL" 2>/dev/null)"

echo "== empty verifier report eval =="
CASE="$ROOT/plugins/flow/evals/pair-empty-verifier-report"
assert 'case names itself' has "$CASE/case.yaml" 'name: pair-empty-verifier-report'
assert 'case runs its scaffold' has "$CASE/case.yaml" 'scaffold_script: scaffold.sh'
assert 'case prompt is the pair slash command' has "$CASE/case.yaml" '/flow:pair 02'
assert 'scaffold seeds a high-risk story' has_re "$CASE/scaffold.sh" 'Risk: item [1-6]'
assert 'grader expects NEEDS DECISION' has "$CASE/graders/needs-decision.md" 'NEEDS DECISION'
assert 'grader expects the story left open' has "$CASE/graders/story-open.md" '[x]'

echo "== steps loop on the focused test =="
# Story tiered-checks/04: red, green, refactor and "do N" run the focused
# test; the full Test command waits for the final tree in step 6.
green_line=$(grep -E '^   3\. Minimal code to pass' "$SKILL" 2>/dev/null)
refactor_line=$(grep -E '^   5\. Optional `refactor' "$SKILL" 2>/dev/null)
do_n_line=$(grep -E '^   "do N" runs' "$SKILL" 2>/dev/null)
# shellcheck disable=SC2016 # literal markdown backticks
assert 'green reruns the focused test' grep -qF 'rerun the focused test' <<<"$green_line"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'green no longer loops on the Test command' \
  test -n "$green_line" -a -z "$(grep -F 'the `Test command:` until green' <<<"$green_line")"
assert 'refactor reruns the focused test' grep -qF 'the focused test reruns after it' <<<"$refactor_line"
assert 'do N keeps the focused test' grep -qF 'green each on the focused test' <<<"$do_n_line"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'the focused test falls back to the Test command' \
  has "$SKILL" 'The focused test is the `Single test:` command, or the `Test command:` when the backlog has no `Single test:` or it is `none`.'
red_line=$(grep -E '^   1\. Write the test;' "$SKILL" 2>/dev/null)
assert 'red runs the focused test' grep -qF 'run it with the focused test' <<<"$red_line"

echo "== the full suite runs on the final tree =="
check_line=$(grep -E '^6\. \*\*Check\.\*\*' "$SKILL" 2>/dev/null)
# shellcheck disable=SC2016 # literal markdown backticks
assert 'check runs the Test command once on the final tree' \
  grep -qF 'run the `Test command:` once on the final tree' <<<"$check_line"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'check carries the long-run wording' \
  grep -qF '(allow up to 10 minutes (Claude: Bash `timeout` 600000), or run it in the background and read the result)' <<<"$check_line"
assert 'check reruns after a fix, before the recheck and before the merge offer' \
  grep -qF "again after any step-6 fix, before the verifier's recheck and before the merge offer" <<<"$check_line"

echo "== a green full run is not repeated =="
# shellcheck disable=SC2016 # literal markdown backticks
assert 'a full run repeats only after a change, from its recorded HEAD' \
  grep -qF 'A full run is repeated only when something changed since the last green full run: record that run'"'"'s `HEAD`, and rerun when the tree is dirty or `git diff --name-only <sha>` lists anything besides the story file and the backlog' <<<"$check_line"
assert 'the verifier run counts only with its command and pass line' \
  grep -qF "the verifier's own run counts only when its report shows the command and its pass line" <<<"$check_line"
# shellcheck disable=SC2016 # literal markdown backticks
assert 'the docs close commit does not force a rerun' \
  grep -qF 'the `docs:` close commit does not invalidate it' <<<"$check_line"

echo "== a red final suite starts a regression round =="
# Story tiered-checks/05: regressions in existing tests are fixed inside
# step 6, one fix: per failing test, with no new test: commit.
# shellcheck disable=SC2016 # literal markdown backticks
assert 'a red final suite on tests the story did not add starts a regression round' \
  grep -qF 'If it is red on tests the story did not add, run a regression round: for each failing existing test, show its output (no `test:` commit, no red marker), commit one `fix:`, rerun that test file and log the `fix:` in the story `## Log` naming the test it turns green' <<<"$check_line"

echo "== strict tdd =="
for s in 'Three Laws' 'Triangulat' 'Banned assertion' 'layer'; do
  assert "strict-tdd covers \"$s\"" has "$TDD" "$s"
done
assert 'strict-tdd drops SDD wiring' test -f "$TDD" -a -z "$(grep -iw 'sdd' "$TDD" 2>/dev/null)"

echo "== work-unit-commits exception =="
assert 'work-unit-commits names /flow:pair' has "$WUC" '/flow:pair'

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All cases passed"
