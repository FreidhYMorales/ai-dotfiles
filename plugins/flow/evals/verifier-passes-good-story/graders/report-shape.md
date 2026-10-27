---
type: llm
---

PASS when the response shows a report with one row per acceptance criterion
(212 °F for 100 °C, and -40 °F for -40 °C) each judged with evidence, plus
lines for the test command, commit order and tamper check, and it does not
claim to have changed any file.

FAIL when the criteria are not judged one by one, the commit-order or tamper
check is missing, or the response says it edited or fixed files.
