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

| Profile | Primary use | Extends |
|---|---|---|
| `info` | reports, document analysis, prose | (base) |
| `research` | technical research, doc reading, no code writing | `info` |
| `paper` | academic paper writing — LaTeX, peer review | `research` |
| `code` | code-centric projects | `info` (not `research`) |

## Profile contents matrix

Everything each profile ships on top of the base, by surface. Legend: ✓ = added here; `✓ᵢ` = inherited.

### Post-init totals

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 10 | 1 | — | — | 4 |
| `research` | 9 | 13 | 1 | — | — | 4 |
| `paper` | 9 | 21 | 11 | 5 | 3 | 5 |
| `code` | 9 | 14 | 1 | — | — | 4 |

### Plugins

8 baseline plugins are enabled in every profile: `superpowers`, `commit-commands`, `claude-md-management`, `session-report`, `hookify`, `claude-code-setup`, `feature-dev`, `elements-of-style`. Profiles add:

| Plugin | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `context7@external-plugins` (library docs lookup via MCP) | — | ✓ | ✓ᵢ | ✓ |

### Rules

Base (shipped regardless of profile): `autonomous-work`, `pr-discipline`, `project-conventions`.

| Rule | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `writing-quality.md` — prose conventions, banned AI-isms | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `summary-parity.md` — don't surgical-patch drifting summaries, rewrite structurally | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `exploration-fast-track.md` — 60/100 quality threshold for experimental work | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `exploration-folder-protocol.md` — `explorations/` sandbox lifecycle | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `meta-governance.md` — template-vs-working-project distinction, two-tier memory | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `session-logging.md` — three-trigger logging discipline | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `content-invariants.md` — numbered invariants pattern for agents to cite | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `citation-discipline.md` — never cite from memory, verify before citing | — | ✓ | ✓ᵢ | — |
| `reading-before-editing.md` — read entire file before edits to research docs | — | ✓ | ✓ᵢ | — |
| `pdf-processing.md` — safe large-PDF chunked workflow | — | ✓ | ✓ᵢ | — |
| `latex-bibtex-discipline.md` — LaTeX + BibTeX conventions | — | — | ✓ | — |
| `humanize-prose.md` — how to use the humanizer skill | — | — | ✓ | — |
| `tikz-prevention.md` — 6-rule protocol for safe TikZ | — | — | ✓ | — |
| `tikz-library-bundle.md` — canonical preamble + specialty packages | — | — | ✓ | — |
| `tikz-snippets/` — 5 canonical compilable standalone figures | — | — | ✓ | — |
| `post-flight-verification.md` — Chain-of-Verification discipline | — | — | ✓ | — |
| `proofreading-protocol.md` — three-phase propose → approve → apply | — | — | ✓ | — |
| `cross-artifact-review.md` — paper review auto-invokes code review on referenced scripts | — | — | ✓ | — |
| `makefile-conventions.md` — standard Make targets | — | — | — | ✓ |
| `devbox-usage.md` — devbox idioms and CI parity | — | — | — | ✓ |
| `testing-discipline.md` — TDD, 80% coverage, isolation | — | — | — | ✓ |
| `verification-before-done.md` — the "am I actually done?" gate | — | — | — | ✓ |

### Skills

Invoke via slash commands (e.g., `/humanizer`, `/verify-claims`).

| Skill | Source | info | research | paper | code |
|---|---|:-:|:-:|:-:|:-:|
| `permission-check` | [pedrohcgs](https://github.com/pedrohcgs/claude-code-my-workflow) | ✓ | ✓ᵢ | ✓ᵢ | ✓ᵢ |
| `humanizer` | [groundnuty/humanizer](https://github.com/groundnuty/humanizer) (git upstream, refreshable) | — | — | ✓ | — |
| `analyze-paper` | vendored (local), generalized from ccgrid2026 | — | — | ✓ | — |
| `tikz` | [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) — 6-pass collision audit | — | — | ✓ | — |
| `verify-claims` | pedrohcgs — CoVe via forked subagent | — | — | ✓ | — |
| `validate-bib` | pedrohcgs — structural + semantic bib validation | — | — | ✓ | — |
| `respond-to-referees` | pedrohcgs — R&R response letter generator | — | — | ✓ | — |
| `seven-pass-review` | pedrohcgs — 7 parallel forked review lenses | — | — | ✓ | — |
| `proofread` | pedrohcgs — three-phase editorial pass | — | — | ✓ | — |
| `review-paper` | pedrohcgs — single-pass + adversarial modes | — | — | ✓ | — |
| `audit-reproducibility` | pedrohcgs — cross-check numeric claims against code | — | — | ✓ | — |

### Agents (dispatched via `Task`/`Agent`)

| Agent | Source | paper |
|---|---|:-:|
| `claim-verifier` | pedrohcgs | ✓ |
| `proofreader` | pedrohcgs | ✓ |
| `editor` | pedrohcgs — desk review + picks 2 disagreeing referees | ✓ |
| `methods-referee` | pedrohcgs — methods/rigor review | ✓ |
| `domain-referee` | pedrohcgs — substantive review with disposition | ✓ |

### Hooks (opt-in — reference from your `.claude/settings.local.json` to enable)

| Hook | paper |
|---|:-:|
| `notify.sh` — cross-platform desktop notification on session events | ✓ |
| `log-reminder.py` — stop-hook reminder to update session log | ✓ |
| `verify-reminder.py` — post-Edit reminder to compile/verify academic files | ✓ |

### Templates

| Template | info | paper |
|---|:-:|:-:|
| `requirements-spec.md` — MUST/SHOULD/MAY + CLEAR/ASSUMED/BLOCKED format | ✓ | ✓ᵢ |
| `constitutional-governance.md` — non-negotiables vs preferences | ✓ | ✓ᵢ |
| `exploration-readme.md` — `explorations/` sandbox README | ✓ | ✓ᵢ |
| `session-log.md` — session-log format | ✓ | ✓ᵢ |
| `journal-profile-template.md` — per-venue review calibration | — | ✓ |

### External requirements (documented, not shipped)

| Requirement | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| Scholar Gateway (claude.ai connector — enable once in account) | — | required | required | — |
| `jq` installed (init script dependency) | required | required | required | required |
| `git` installed (for `refresh-skills.sh`) | — | — | required | — |
| devbox installed (recommended) | — | — | — | recommended |
| `/configure-ecc` run (for language-specific skills) | — | — | — | recommended |

### Attribution

The `paper` profile adopts 17 pieces from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT) and 1 from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools). Each vendored file carries an inline attribution header.

## Requirements

- [Claude Code](https://claude.com/claude-code) v2.1.111 or later (for Opus 4.7 support) (needed for `PreCompact` hook with `$CLAUDE_TRANSCRIPT_PATH`, `ConfigChange` hook, `sandbox.failIfUnavailable`).
- `jq` on your `$PATH` (for the init script's deep-merge).
- `git` on your `$PATH` (for the paper profile's upstream-sourced skill refresh; optional otherwise).
- **Scholar Gateway** claude.ai connector — enable in claude.ai account settings if using `research` or `paper` profiles.

## What's in the template

### Base `.claude/` (shipped to every profile)

- `settings.json` — permissions (wildcard allow with bare tool names + 62-entry deny list including `Edit`/`Write` to sensitive paths), sandbox (OS-level enforcement, `failIfUnavailable: true`), plugins (8 baseline), hooks (SessionStart / ConfigChange / PreCompact / SessionEnd), env (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `ENABLE_LSP_TOOL=1`), `effortLevel: xhigh` + `verbose: true` tuned for Opus 4.7 agentic work.
- `CLAUDE.md` — project-conventions stub. Each profile appends a `CLAUDE.append.md` overview on init.
- `rules/` — three base rules: `autonomous-work.md`, `pr-discipline.md`, `project-conventions.md`.
- `audit.log` — committed to git; `ConfigChange` hook appends a line on every `.claude/*` modification.
- `session-reports/` — session transcripts and git-state snapshots from `PreCompact` / `SessionEnd` hooks.

### Post-init leftovers

- `refresh-skills.sh` — re-fetch upstream-sourced skills (currently: `humanizer` in the paper profile).

### Escape hatch

- `~/.claude/settings.local.json` or `.claude/settings.local.json` (gitignored) — merge with base at load time. Per-project `allow`/`ask`/`deny` overrides and hook activations live here.

## Updating the template or debating decisions

All design research, empirical data, and decision rationale live in a companion repo: [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private). Before changing the template, read the research there.

## License

MIT. See `LICENSE`.
