# Changelog

User-facing history of this template. Every version is a git tag with a matching GitHub Release; `main` is always the latest stable release.

Design rationale, empirical research, and decision history live in [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research).

---

## [v0.1.5] — 2026-04-17

Documentation polish. No new features.

- **README**: detailed profile contents matrix. Every plugin / rule / skill / agent / hook / template listed by exact name with per-profile ✓/— columns. New "what's common vs specific" summary up front.

---

## [v0.1.4] — 2026-04-16

Major `paper` profile expansion. 17 pieces adopted from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT) covering anti-hallucination, peer review, bibliography validation, revise-resubmit, proofreading, exploration sandbox.

**New skills** (paper profile):
- `verify-claims` — Chain-of-Verification via forked subagent
- `validate-bib` — structural + semantic bibliography validation
- `respond-to-referees` — R&R response letter generator
- `seven-pass-review` — 7 parallel forked review lenses
- `proofread` — three-phase propose → approve → apply
- `review-paper` — single-pass + adversarial modes
- `audit-reproducibility` — cross-check numeric claims against code

**New skill** (info profile — inherited by all profiles):
- `permission-check` — diagnose Claude Code's 6-tier permission stack

**New agents** (paper, dispatched via Task/Agent):
- `claim-verifier`, `proofreader`, `editor`, `methods-referee`, `domain-referee`

**New rules**:
- Paper: `post-flight-verification`, `proofreading-protocol`, `cross-artifact-review`
- Info: `summary-parity`, `exploration-fast-track`, `exploration-folder-protocol`, `meta-governance`, `session-logging`, `content-invariants`
- Research: `pdf-processing`

**New opt-in hooks** (paper, reference from `settings.local.json` to activate):
- `notify.sh`, `log-reminder.py`, `verify-reminder.py`

**New templates**:
- Info: `requirements-spec`, `constitutional-governance`, `exploration-readme`, `session-log`
- Paper: `journal-profile-template`

**init.sh extended**: `copy_profile_content` now handles `agents/`, `hooks/`, `templates/` subdirectories alongside the existing `rules/` and `skills/`. Backward-compatible.

**Post-init counts**:

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 10 | 1 | — | — | 4 |
| `research` | 9 | 13 | 1 | — | — | 4 |
| `paper` | 9 | 21 | 11 | 5 | 3 | 5 |
| `code` | 9 | 14 | 1 | — | — | 4 |

---

## [v0.1.3] — 2026-04-16

Vendored MixtapeTools `/tikz` collision-audit skill into the paper profile.

- `paper/skills/tikz/` — 6-pass visual-collision audit using mathematical gap calculations (label-on-arrow, boundary overlaps, crossing arrows, Bézier depth formulas). Adapted from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) with attribution. MixtapeTools-specific references (`/beautiful_deck`, `~/mixtapetools/...`) stripped.

---

## [v0.1.2] — 2026-04-16

TikZ tooling additions and `verbose` default.

- `settings.json`: `verbose: true` by default. Surfaces thinking summaries and detailed transcript output — valuable for async review of autonomous-work sessions.
- `paper/rules/tikz-prevention.md` — 6-rule protocol to prevent TikZ failure modes (P1 explicit node dimensions, P2 coordinate map, P3 no bare `scale=`, P4 directional edge labels, P5 start from snippets, P6 one tikzpicture per idea). Adapted from MixtapeTools via pedrohcgs.
- `paper/rules/tikz-library-bundle.md` — canonical TikZ preamble (`positioning, arrows.meta, calc, shapes.geometric, shapes.misc, decorations.pathreplacing, patterns, matrix, fit`) + specialty package guide (`tikz-cd`, `pgfplots`, `circuitikz`, `forest`).
- `paper/rules/tikz-snippets/` — 5 compilable standalone figures: `flowchart.tex`, `tree.tex`, `graph.tex`, `plot.tex`, `block-diagram.tex`.

---

## [v0.1.1] — 2026-04-16

Claude Opus 4.7 + Claude Code v2.1.111 support.

- `settings.json`: `effortLevel: "xhigh"`. Anthropic's explicit recommendation for coding/agentic work on Opus 4.7 per the [migration guide](https://platform.claude.com/docs/en/about-claude/models/migration-guide). Older models fall back to `high` gracefully.
- **README**: minimum Claude Code version bumped to **v2.1.111** (for Opus 4.7 support, auto-mode without flag, `/less-permission-prompts` + `/ultrareview` skills).
- `rules/autonomous-work.md`: added "Notes for Opus 4.7+" section documenting behavior changes (more literal instruction following; fewer subagents and tool calls by default — raise effort or ask explicitly; response length calibrated to complexity; real-time cybersecurity safeguards).

---

## [v0.1.0] — 2026-04-15

Initial release. Four profiles (`info` / `research` / `paper` / `code`) applied via self-cleaning `.claude/init.sh` script.

**Base `.claude/`:**
- `settings.json` — 8 baseline plugins (`superpowers`, `commit-commands`, `claude-md-management`, `session-report`, `hookify`, `claude-code-setup`, `feature-dev`, `elements-of-style`), comprehensive deny list with `Edit`/`Write` protection for sensitive paths (ssh, aws, gnupg, kube, gcloud, claude.json, gitconfig, npmrc, pypirc, docker config, netrc, shell init files), OS-level sandbox with `failIfUnavailable: true`, 4 hooks (SessionStart, ConfigChange, PreCompact, SessionEnd), `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `ENABLE_LSP_TOOL=1`, `alwaysThinkingEnabled: true`, `enableAllProjectMcpServers: false`.
- 3 base rules: `autonomous-work.md`, `pr-discipline.md`, `project-conventions.md`.
- `init.sh` — applies profile overlay (deep-merges settings via `jq`, copies rules/skills, appends CLAUDE.md guidance, merges skills.manifest), self-deletes.
- `refresh-skills.sh` — re-fetch upstream-sourced skills (currently `humanizer`).

**Profiles:**
- `info` — `writing-quality.md` rule.
- `research` — inherits info; adds `context7` plugin, `citation-discipline` + `reading-before-editing` rules; documents Scholar Gateway claude.ai connector as an external requirement.
- `paper` — inherits research; adds `latex-bibtex-discipline` + `humanize-prose` rules; vendored `humanizer` (git-upstream-sourced, refreshable) + `analyze-paper` (local) skills.
- `code` — inherits info (not research); adds `context7` plugin, `makefile-conventions` + `devbox-usage` + `testing-discipline` + `verification-before-done` rules; documents `/configure-ecc` + devbox as optional follow-ups.

**Root:**
- `README.md` with usage instructions and profile comparison.
- `CLAUDE.md` stub.
- `.gitignore` with strong secret-pattern block (`.env*`, `*.pem`, `*.key`).
- `LICENSE` — MIT.
