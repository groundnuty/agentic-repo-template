# Autonomous-work rules

Applied to every session. How to behave when operating without immediate human oversight.

## Core discipline

- **Commit early and often.** Every logical unit of work ends in a commit with a clear message. Uncommitted work is lost work if context runs out mid-task.
- **Never force-push.** All variants — `git push --force`, `-f`, `--force-with-lease` — are in the deny list. A history rewrite is the user's call: stop and surface it.
- **Never `--no-verify`.** Pre-commit hooks exist for a reason. If a hook fails, fix the cause.
- **Verify before claiming done.** Run the project's real check command — its test suite, linter, type checker, build — and read the output before saying the work is complete.

## Scope

Deliver what was asked, at the scope intended. If the request seems mistaken or a better approach exists, say so in a sentence and continue as asked rather than quietly narrowing, widening, or transforming it.

## Judgment vs. escalation

- **Make routine judgment calls yourself** and state the assumption in one line.
- **Stop and wait** only when readings differ materially, evidence contradicts the plan, or the action is risky or irreversible. Say plainly what is blocked and what you need. If you are working through a TaskList, mark the task `blocked` with the reason.
- **Prefer surfacing over papering over.** Silent workarounds — suppressing linter rules, mocking what should be real, disabling tests — stay prohibited.
- **Do not widen your own permissions.** If `settings.local.json` does not already allow something you believe you need, surface the need and wait for the user to grant it. Editing the allow list to unblock yourself is not an option.

## Delegation

- Delegate to subagents only for sizeable, genuinely independent tracks. Do not delegate what a handful of tool calls finishes.
- Do not spawn a subagent to re-check work you just did in this context — it inherits your framing. Do keep verifiers that never saw the draft; fresh-context verification is the pattern that works.
- Pin `model:` on dispatches. Keep spawn counts low (defaults: 200 per session, 20 concurrent, nest depth 3).

## Working across machines

Everything shared goes through git — commit and push. Auto-memory is machine-local and never syncs, so durable cross-machine notes belong in committed files.

## Session reporting

- The `PreCompact` hook archives the transcript and prints a reminder to stderr. When you see it, prefer `/rewind` → "Summarize up to here" over letting compaction run blind, then `/session-report`.
- The `SessionEnd` hook captures a final git-state snapshot to `.claude/session-reports/`.

## Where the mechanics live

Config-mechanics notes (MCP allow rules, `Edit(path)`-vs-`Write(path)` file rules, deny-pattern wrapper coverage) live in `.claude/rules/operations.md` and load when you touch settings files. Auto-mode and classifier guidance is user-machine config — see the template README.
