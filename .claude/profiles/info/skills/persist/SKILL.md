---
name: persist
description: Flush everything this session learned into the files that outlive it - AGENTS.md, CLAUDE.md, project-conventions, path-scoped rules, auto-memory, and a checkpoint - each routed to the surface that actually holds it. Use when the user says "update your CLAUDE.md / AGENTS.md / memory / rules", "save what you learned", "write down what you'll need after compaction", "persist state", or when the PreCompact hook warns that context is about to be compressed. The value is the routing - the same fact belongs in different files depending on who needs it and when.
argument-hint: "(no arguments)"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
---

# Persist

## Purpose

A session accumulates knowledge that is worthless once the context is gone. This
skill moves each piece to the file that will still have it tomorrow — and to the
*right* file, which is the part that is easy to get wrong.

## Phase 1 — Inventory

List what this session produced that outlives it. Be concrete; if nothing
qualifies in a category, write `(none)` rather than padding.

- **Corrections the user made** to how you work — especially ones you would
  otherwise repeat.
- **Facts about this project** that were not obvious from the code: why a thing
  is built the way it is, what a command actually does, what breaks.
- **Conventions** agreed during the session.
- **State**: what is in flight, what is blocked, what is next.
- **Dead ends** — things tried that did not work. These save the most time and
  are the most often lost.

## Phase 2 — Route each item

The routing rule is *who needs this, and when*:

| The item is… | Goes to | Why there |
|---|---|---|
| Guidance every agent needs in every session | `AGENTS.md`, **below** the `<!-- END template-managed -->` fence | Read by Claude Code (via the `@AGENTS.md` import), Codex and OpenCode alike |
| A Claude-Code-only instruction | `CLAUDE.md`, below the import line | The other harnesses ignore this file |
| Stack, layout, commands, do-not-touch zones | `.claude/rules/project-conventions.md` | The file that exists for exactly this, and upgrades never overwrite it |
| Guidance that only matters for certain files | a path-scoped rule in `.claude/rules/` with `paths:` frontmatter | Loads only when those files are touched — costs nothing otherwise |
| A machine-local preference or learning | auto-memory (`/memory`) | Never syncs, never commits — right for "on this machine, X" |
| Where-am-I / what-is-next for the next session | run `/checkpoint` | A committed artifact that travels to other machines and collaborators |
| The narrative of what happened | the session log (`.claude/templates/session-log.md`) | Story, not instruction |

**Never write inside the template-managed fence in `AGENTS.md`.** The next
upgrade regenerates that region and your text disappears. Everything you add
goes below `<!-- END template-managed -->`.

**Prefer the narrowest surface that works.** A fact that only matters when
editing `*.tex` belongs in a path-scoped rule, not in the always-on corpus that
every session in every harness pays for.

## Phase 3 — Write, then verify

1. Make each edit. Keep entries short — one line per fact where possible; these
   files are read every session and length costs adherence.
2. Do not duplicate: if a rule already says it, sharpen that line instead of
   adding a second one. Grep before you write.
3. Verify: `grep -c "template-managed" AGENTS.md` still returns 2, and
   `git diff --stat` shows only the files you intended.
4. Report what went where, in one line each, so the user can correct the routing
   before it hardens.

## When not to use

- Mid-task, for something you will use in the next five minutes — that is what
  the conversation is for.
- To record speculation. If you are unsure a fact is durable, say so and let the
  user decide rather than committing a guess to a file every future session reads.
