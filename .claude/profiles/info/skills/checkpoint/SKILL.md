---
name: checkpoint
description: Save a structured state snapshot before stopping or handing off - active plan, decisions made, file pointers with line numbers, open questions, and the next 1-3 concrete actions - written to `.claude/session-reports/`. Use when the user says "checkpoint", "save state", "snapshot before I stop", "where am I", "wrap up for handoff", or before a long break, a model switch, or handing the repo to a collaborator. Structured counterpart to the narrative session log, not a replacement for it.
argument-hint: "[short-topic-slug]"
disable-model-invocation: true
allowed-tools: ["Read", "Write", "Bash"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Checkpoint

## Purpose

Write a state snapshot the next session can resume from in under a minute — yours after a break, a collaborator's, or a fresh context after compaction. The session log answers *what happened and why*. The checkpoint answers *where am I and what is next*: facts, file pointers, and actions.

## When to use

- Before a long break, a model switch, or the end of a working day.
- When the `PreCompact` hook warns that compaction is imminent and mid-plan context is about to be compressed.
- Before handing the repo to a collaborator.
- After finishing a chunk of multi-session work, when "where was I" is the first question the next session will ask.

## When not to use

- For the narrative of the session — that is the session log (`.claude/rules/session-logging.md`, template `.claude/templates/session-log.md`). The checkpoint links to the latest log by path; it does not retell it.
- As a substitute for committing. Uncommitted work is still lost work: commit first, then checkpoint. See `.claude/rules/autonomous-work.md`.

## Phase 1 — Gather state

Read these in order. If a source is missing, record `(none on disk)` rather than inventing content.

1. **Git state** — `git branch --show-current`, `git status -s`, `git log --oneline -10`, `git diff --stat HEAD`. Capture the branch, uncommitted file count, recent subjects, and files touched this session.
2. **Latest session log** — `ls -t .claude/session-reports/session_logs/*.md 2>/dev/null | head -1`. Pull its open questions, blockers, and next steps.
3. **Previous checkpoint** — `ls -t .claude/session-reports/*_checkpoint_*.md 2>/dev/null | head -1`. Note what it said was next, and whether that happened.
4. **Active plan or spec** — whatever this repo keeps on disk (e.g. `docs/plans/`, per `.claude/rules/pr-discipline.md`). Pull its status, files-to-modify list, and open questions.
5. **In-flight TODOs** — if a TodoWrite list is live in this session, capture the in-progress item and the next pending ones.

## Phase 2 — Write the checkpoint

Write to `.claude/session-reports/YYYY-MM-DD_checkpoint_<slug>.md`. Take the slug from `$ARGUMENTS`; with no argument, derive one from the branch name and say which slug you used.

```markdown
---
date: YYYY-MM-DD
branch: <current branch>
status: in_progress | paused | ready-to-merge
session-log: <path, or (none)>
plan: <path, or (none)>
---

# Checkpoint — <short topic>

## Goal

<One sentence: what this work is trying to accomplish.>

## Where I am

<One short paragraph or 3-5 bullets: last step completed, step in progress, what has not started.>

## File pointers

<3-8 concrete `path:line` references marking where the next session resumes.>

- `path/to/file.ext:142` — half-written handler, error branch missing
- `docs/design.md:30` — section to update once the above lands

## Decisions made

<2-5 bullets on why the work took the shape it did — what the diff does not explain. Omit the section entirely if there were none; do not pad.>

## Open questions

<Specific things you would ask if someone else picked this up. Number them Q1, Q2, ...>

## Next actions

1. <Imperative. Concrete. The next session starts here.>
2. <...>
3. <...>

## Resume prompt

> Resuming from `.claude/session-reports/<filename>`. Read it, then start at action 1.
```

Cap the file at ~80 lines. If the state does not fit, the plan file is the right home for the detail — the checkpoint is a thin index pointing at it.

## Phase 3 — Report

Print to chat:

```
Checkpoint saved: .claude/session-reports/<filename>
  Branch: <branch>   Status: <status>   Uncommitted: <N> files
  Session log: <path or none>   Open questions: <count>
  Resume: `claude --continue`, or paste the checkpoint's resume prompt into a fresh session.
```

## Notes

- `.claude/session-reports/` is where the `PreCompact` and `SessionEnd` hooks already write their git-state snapshots, so a checkpoint sorts alongside the automatic ones and survives the same way.
- **Uncommitted work.** Flag it in the report and offer to commit before writing the checkpoint. A checkpoint describing state that lives only in a dirty worktree is fragile.
- **No slug, no branch to derive from.** Ask the user for one word rather than guessing a topic.
- **Nothing to point at.** If the file-pointers section would come out empty, nothing changed this session — a session log line is the better artifact and the checkpoint is premature.
