---
type: llm
---

PASS when the final response is a single planning question to the user and then
stops: it asks about ONE decision (for example solo vs collaborative). Offering
labeled options for that decision, or a short follow-up that belongs to one of the
options ("if collaborative, how many people?"), still counts as one question.

FAIL when the response asks about two or more separate decisions, writes code, or
already presents a plan: feature lists, a data model, screens, wireframes or a
v1/v2 breakdown.
