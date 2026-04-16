# agentic-repo-template

A GitHub template repository with sane Claude Code defaults for autonomous work. Four profiles (`info` / `research` / `paper` / `code`) cover knowledge work, technical research, academic paper writing, and code-centric development.

## Quick start

1. On GitHub, click **Use this template → Create a new repository**.
2. Clone your new repo locally.
3. Pick a profile and run the init script:

```bash
./.claude/init.sh info        # knowledge / prose work only
./.claude/init.sh research    # technical research, doc reading
./.claude/init.sh paper       # academic paper writing
./.claude/init.sh code        # code-centric projects
```

The script merges the profile's overlay into `.claude/settings.json`, copies profile-specific rules into `.claude/rules/`, appends profile guidance to `.claude/CLAUDE.md`, vendors profile-specific skills into `.claude/skills/`, then removes `.claude/profiles/` and `.claude/init.sh` themselves. Your repo ends up with only the final configuration.

## Profiles at a glance

| Profile | Adds | Typical use |
|---|---|---|
| `info` | writing-quality rule | reports, document analysis, prose |
| `research` | + context7 plugin, citation-discipline rule, reading-before-editing rule | technical research, doc reading, no code writing |
| `paper` | + LaTeX/BibTeX rule, humanize-prose rule, vendored `humanizer` + `analyze-paper` skills | academic paper writing |
| `code` | + context7 plugin, Makefile/devbox/testing/verification rules | code-centric work |

## Requirements

- [Claude Code](https://claude.com/claude-code) v2.1.111 or later (for Opus 4.7 support) (needed for `PreCompact` hook with `$CLAUDE_TRANSCRIPT_PATH`, `ConfigChange` hook, `sandbox.failIfUnavailable`).
- `jq` on your `$PATH` (for the init script's deep-merge).
- `git` on your `$PATH` (for the paper profile's upstream-sourced skill refresh; optional otherwise).
- **Scholar Gateway** claude.ai connector — enable in claude.ai account settings if using `research` or `paper` profiles.

## What's in the template

### Base `.claude/`

- `settings.json` — permissions (wildcard allow with bare tool names + comprehensive deny list), sandbox (OS-level enforcement), plugins (8 baseline), hooks (SessionStart / ConfigChange / PreCompact / SessionEnd), env (subprocess credential scrubbing).
- `CLAUDE.md` — project-conventions stub with placeholder sections.
- `rules/` — three base rules: `autonomous-work.md`, `pr-discipline.md`, `project-conventions.md`.
- `audit.log` — committed to git; `ConfigChange` hook appends a line on every `.claude/*` modification.
- `session-reports/` — session transcripts and git-state snapshots from `PreCompact` / `SessionEnd` hooks.

### Post-init leftovers

- `refresh-skills.sh` — re-fetch upstream-sourced skills (currently: `humanizer` in the paper profile).

### Escape hatch

- `~/.claude/settings.local.json` or `.claude/settings.local.json` (gitignored) — merge with base at load time. Per-project `allow`/`ask`/`deny` overrides live here.

## Updating the template or debating decisions

All design research, empirical data, and decision rationale live in a companion repo: [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private). Before changing the template, read the research there.

## License

MIT. See `LICENSE`.
