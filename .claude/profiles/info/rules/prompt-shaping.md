<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Prompt shaping

When a request arrives informal, dictated, or ambiguous, shape it before acting on it — silently. Resolve five things from the repo yourself: **role** (whose expertise answers this), **task** (one concrete deliverable), **context** (which files and prior decisions bear on it), **constraints** (house style, no new dependencies, reproducibility), **output format** (report, diff, table, plan).

Surface only the genuine decision — one that is the user's to make — asked once via `AskUserQuestion`. One line of stated assumptions ("assuming you want this edited in place, not copied") beats a five-question interrogation.

Skip the pass on requests already explicit: a named file, a specific command, a settled follow-up.
