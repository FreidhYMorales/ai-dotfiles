Bash:
- Quote every variable expansion ("$x"). Scripts use `set -u`, so give optional variables a default: ${X:-}.
- Run `shellcheck FILE` and fix every finding. Indent with 2 spaces; `case` branches are indented under `case`.
