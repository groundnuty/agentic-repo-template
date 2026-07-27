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

See `.claude/rules/` for the rule set (some load every session, some only when matching files are touched):

- `autonomous-work.md` — how to behave when running unattended (always)
- `pr-discipline.md` — commit message format and PR structure (always)
- `operations.md` — config mechanics: permission rules, MCP allow entries, deny-pattern coverage (when touching settings/MCP files)
- `project-conventions.md` — per-project overrides (fill in per project)

<!-- Profile-specific rules are listed here by `.claude/init.sh`. -->
