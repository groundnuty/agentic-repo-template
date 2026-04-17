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

Every artifact by exact name, one row per item. Cell `✓` means the artifact is present in that profile after running `init.sh`. Items are grouped by surface (plugins / rules / skills / agents / hooks / templates) and within each surface ordered by commonality — items present in all four profiles come first, then items in three, two, one.

### Post-init totals

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 10 | 1 | — | — | 4 |
| `research` | 9 | 13 | 1 | — | — | 4 |
| `paper` | 9 | 21 | 11 | 5 | 3 | 5 |
| `code` | 9 | 14 | 1 | — | — | 4 |

### What's common vs specific at a glance

- **In all four profiles** (base + info): 8 plugins, 10 rules, 1 skill, 4 templates.
- **In three profiles** (`research` + `paper` + `code` — *not* `info`): 1 plugin (`context7`).
- **In two profiles** (`research` + `paper`): 3 rules (`citation-discipline`, `reading-before-editing`, `pdf-processing`).
- **Paper-only**: 8 rules, 10 skills, 5 agents, 3 hooks, 1 template.
- **Code-only**: 4 rules.

### Plugins (9 unique, `context7` conditional)

| Plugin | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `superpowers@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `commit-commands@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `claude-md-management@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `session-report@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `hookify@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `claude-code-setup@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `feature-dev@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ |
| `elements-of-style@superpowers-marketplace` | ✓ | ✓ | ✓ | ✓ |
| `context7@external-plugins` | — | ✓ | ✓ | ✓ |

### Rules (25 unique)

| Rule | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `autonomous-work.md` — how to behave unattended | ✓ | ✓ | ✓ | ✓ |
| `pr-discipline.md` — commit/PR format | ✓ | ✓ | ✓ | ✓ |
| `project-conventions.md` — per-project overrides (stub) | ✓ | ✓ | ✓ | ✓ |
| `writing-quality.md` — prose conventions, banned AI-isms | ✓ | ✓ | ✓ | ✓ |
| `summary-parity.md` — don't surgical-patch drifting summaries | ✓ | ✓ | ✓ | ✓ |
| `exploration-fast-track.md` — 60/100 threshold for experiments | ✓ | ✓ | ✓ | ✓ |
| `exploration-folder-protocol.md` — `explorations/` lifecycle | ✓ | ✓ | ✓ | ✓ |
| `meta-governance.md` — template vs working project, 2-tier memory | ✓ | ✓ | ✓ | ✓ |
| `session-logging.md` — three-trigger logging discipline | ✓ | ✓ | ✓ | ✓ |
| `content-invariants.md` — numbered invariants for agents to cite | ✓ | ✓ | ✓ | ✓ |
| `citation-discipline.md` — never cite from memory | — | ✓ | ✓ | — |
| `reading-before-editing.md` — full read before research edits | — | ✓ | ✓ | — |
| `pdf-processing.md` — safe large-PDF chunked workflow | — | ✓ | ✓ | — |
| `latex-bibtex-discipline.md` — LaTeX + BibTeX conventions | — | — | ✓ | — |
| `humanize-prose.md` — how to use the humanizer skill | — | — | ✓ | — |
| `tikz-prevention.md` — 6-rule protocol for safe TikZ | — | — | ✓ | — |
| `tikz-library-bundle.md` — canonical preamble + specialty packages | — | — | ✓ | — |
| `tikz-snippets/` — 5 compilable standalone figures + README | — | — | ✓ | — |
| `post-flight-verification.md` — Chain-of-Verification discipline | — | — | ✓ | — |
| `proofreading-protocol.md` — three-phase propose → approve → apply | — | — | ✓ | — |
| `cross-artifact-review.md` — paper review auto-invokes code review | — | — | ✓ | — |
| `makefile-conventions.md` — standard Make targets | — | — | — | ✓ |
| `devbox-usage.md` — devbox idioms and CI parity | — | — | — | ✓ |
| `testing-discipline.md` — TDD, 80% coverage, isolation | — | — | — | ✓ |
| `verification-before-done.md` — "am I actually done?" gate | — | — | — | ✓ |

### Skills (11 unique; invoke via `/<name>`)

| Skill | Source | info | research | paper | code |
|---|---|:-:|:-:|:-:|:-:|
| `permission-check` | pedrohcgs | ✓ | ✓ | ✓ | ✓ |
| `humanizer` | [groundnuty/humanizer](https://github.com/groundnuty/humanizer) (git upstream, refreshable) | — | — | ✓ | — |
| `analyze-paper` | local (generalized from a ccgrid2026 paper repo) | — | — | ✓ | — |
| `tikz` | [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) — 6-pass collision audit | — | — | ✓ | — |
| `verify-claims` | [pedrohcgs](https://github.com/pedrohcgs/claude-code-my-workflow) — CoVe via forked subagent | — | — | ✓ | — |
| `validate-bib` | pedrohcgs — structural + semantic bib validation | — | — | ✓ | — |
| `respond-to-referees` | pedrohcgs — R&R response letter generator | — | — | ✓ | — |
| `seven-pass-review` | pedrohcgs — 7 parallel forked review lenses | — | — | ✓ | — |
| `proofread` | pedrohcgs — three-phase editorial pass | — | — | ✓ | — |
| `review-paper` | pedrohcgs — single-pass + adversarial modes | — | — | ✓ | — |
| `audit-reproducibility` | pedrohcgs — cross-check numeric claims against code | — | — | ✓ | — |

### Agents (5 unique — paper only)

Dispatched via `Task`/`Agent` subagents, not directly by the user.

| Agent | Source | info | research | paper | code |
|---|---|:-:|:-:|:-:|:-:|
| `claim-verifier.md` | pedrohcgs — fresh-context CoVe verifier | — | — | ✓ | — |
| `proofreader.md` | pedrohcgs — grammar/typo/overflow review | — | — | ✓ | — |
| `editor.md` | pedrohcgs — desk review + picks 2 disagreeing referees | — | — | ✓ | — |
| `methods-referee.md` | pedrohcgs — methods/rigor review | — | — | ✓ | — |
| `domain-referee.md` | pedrohcgs — substantive review with disposition | — | — | ✓ | — |

### Hooks (3 unique, paper only — opt-in, reference from `settings.local.json` to enable)

| Hook | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `notify.sh` — cross-platform desktop notification on session events | — | — | ✓ | — |
| `log-reminder.py` — stop-hook reminder to update session log | — | — | ✓ | — |
| `verify-reminder.py` — post-Edit reminder to compile/verify academic files | — | — | ✓ | — |

### Templates (5 unique)

| Template | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| `requirements-spec.md` — MUST/SHOULD/MAY + CLEAR/ASSUMED/BLOCKED format | ✓ | ✓ | ✓ | ✓ |
| `constitutional-governance.md` — non-negotiables vs preferences | ✓ | ✓ | ✓ | ✓ |
| `exploration-readme.md` — `explorations/` sandbox README | ✓ | ✓ | ✓ | ✓ |
| `session-log.md` — session-log format | ✓ | ✓ | ✓ | ✓ |
| `journal-profile-template.md` — per-venue review calibration | — | — | ✓ | — |

### External requirements (documented, not shipped)

| Requirement | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| Scholar Gateway (claude.ai connector — enable once in account) | — | required | required | — |
| `jq` installed (init script dependency) | required | required | required | required |
| `git` installed (for `refresh-skills.sh`) | — | — | required | — |
| devbox installed (recommended) | — | — | — | recommended |
| `/configure-ecc` run (for language-specific skills) | — | — | — | recommended |

### Attribution

The `paper` profile adopts 17 pieces from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT), 1 from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) (use freely, attribution appreciated), and 1 from [groundnuty/humanizer](https://github.com/groundnuty/humanizer) (git-upstream-sourced, refreshable via `refresh-skills.sh`). Each vendored file carries an inline attribution header.

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

## Versioning and release model

This is the **release artifact** repo. Development happens in the sibling [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private) — this repo is what "Use this template" consumes and is always release-ready.

- **`main`** is always the **latest stable release**. Every commit merged here has passed the test suite in the research repo.
- **Git tags** (`v0.1.0`, `v0.1.1`, …) are addressable snapshots — useful if you want to pin a specific version.
- **GitHub Releases** (visible at the repo's [Releases](https://github.com/groundnuty/agentic-repo-template/releases) page) correspond 1:1 with tags and carry release notes.
- **[CHANGELOG.md](./CHANGELOG.md)** — user-facing release notes per version.

### "Use this template" gives you `main @ HEAD` (= latest release)

GitHub's "Use this template" button always copies from the default branch at HEAD. It does not offer tag selection. So:

- Click the button → you get the latest stable version.
- Need an older version? Clone, then `git checkout v0.1.4` (or whichever tag) before running `init.sh`.

### Semantic versioning policy

Currently `v0.1.x` (pre-stable). Minor bumps are additive; breaking changes go in CHANGELOG as **BREAKING**.

Post-`v1.0.0`:
- **MAJOR** — breaking changes (removed plugin, changed `init.sh` CLI, changed `settings.json` schema requirements).
- **MINOR** — new profile, new plugin added to baseline, new rule shipped.
- **PATCH** — documentation fixes, small rule-content adjustments, refreshed vendored skills.

---

## Updating the template or debating decisions

All design research, empirical data, and decision rationale live in a companion repo: [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private). Before changing the template, read the research there.

## License

MIT. See `LICENSE`.
