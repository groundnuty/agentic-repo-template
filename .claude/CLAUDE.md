# Project conventions for Claude Code

<!-- Base stub. Profile-specific content is appended by `.claude/init.sh` per `profiles/<name>/CLAUDE.append.md`. -->

## Project overview

<!-- 1-2 sentences. What is this project, who it serves, what archetype it belongs to (info / research / paper / code). -->

## Build, test, run

<!-- Exact commands. If using devbox: `devbox run -- make check`. -->

## Common tasks

<!-- 3-5 most-frequent operations, each as a one-liner command. -->

## Notable files

<!-- Path -> purpose, one per line. -->

## Rules applied

The always-on instructions live in **`AGENTS.md`** at the repo root. Every harness
reads them: Codex and OpenCode natively, Claude Code through the `@AGENTS.md`
import in the root `CLAUDE.md`. Do not copy them here — one source, no drift.

`.claude/rules/` holds only what is Claude-specific or conditional:

- `operations.md` — config mechanics (loads when you touch settings/MCP files)
- `project-conventions.md` — per-project overrides (fill in per project)
- path-scoped rules — load only when you touch files matching their `paths:`

<!-- Profile-specific rules are listed here by `.claude/init.sh`. -->
