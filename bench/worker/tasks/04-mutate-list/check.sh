#!/usr/bin/env bash
# Hidden check: --list prints mutants and runs no tests.
set -u
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
git -C "$d" init -q
# shellcheck disable=SC2016 # literal $1/$x: the fixture script's own source.
printf '#!/usr/bin/env bash\n# comment\nif [[ $1 -gt $2 ]]; then echo a; fi\n[[ -z $x ]] && exit 0\n' >"$d/m.sh"
out=$(cd "$d" && bash "$OLDPWD/scripts/mutate.sh" --list m.sh 2>&1)
rc=$?
[[ $rc -eq 0 ]] || {
  echo "exit $rc: $out"
  exit 1
}
[[ $out == *"line 3:"*"-le"* ]] || {
  echo "missing -gt mutant: $out"
  exit 1
}
[[ $out == *"line 4:"* ]] || {
  echo "missing line 4 mutants: $out"
  exit 1
}
[[ $out != *"line 2:"* ]] || {
  echo "mutated a comment: $out"
  exit 1
}
[[ $out != *score:* ]] || {
  echo "it ran the mutation loop: $out"
  exit 1
}
