# Verification harness: agent output is accepted when `make check` passes.
# `check` runs every step and prints a summary; the sub-targets run one area.
.PHONY: check lint validate test

check:
	@bash scripts/check.sh

lint:
	@bash scripts/check-shell.sh
	@bash scripts/check-skills.sh

validate:
	@bash scripts/check-json.sh
	@bash scripts/check-structure.sh
	@bash scripts/check-settings.sh

test:
	@bash scripts/run-tests.sh
