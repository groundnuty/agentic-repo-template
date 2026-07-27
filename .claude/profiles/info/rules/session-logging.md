<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Session Logging

**Location:** `.claude/session-reports/session_logs/YYYY-MM-DD_description.md`
**Template:** `templates/session-log.md`

Native auto-memory handles cross-session continuity automatically and is machine-local; the session log exists because it is committed — the repo-visible record of autonomous work.

## Three Triggers (all proactive)

### 1. Post-Plan Log

After plan approval, immediately capture: goal, approach, rationale, key context.

### 2. Incremental Logging

Append 1-3 lines whenever: a design decision is made, a problem is solved, the user corrects something, or the approach changes. Do not batch.

### 3. End-of-Session Log

When wrapping up: high-level summary, quality scores, open questions, blockers.

## Quality Reports

Generated **only at merge time** -- not at every commit or PR.
Save to `.claude/session-reports/merges/YYYY-MM-DD_[branch-name].md` using `templates/quality-report.md`.
