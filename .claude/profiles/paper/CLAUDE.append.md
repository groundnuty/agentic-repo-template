<!-- Profile: paper -->

## Profile: paper

Academic paper writing — LaTeX/BibTeX, literature review, prose polishing, structured peer review.

### Scholar Gateway

Same one-time setup as the `research` profile. Scholar Gateway + Google Scholar WebSearch fallback both active for this profile.

### Vendored skills

This profile vendors two skills into `.claude/skills/`:
- `humanizer` — removes AI-writing patterns from prose. Invoke via `/humanizer`. Upstream: https://github.com/groundnuty/humanizer
- `analyze-paper` — structured analysis of a reference paper PDF. Invoke via `/analyze-paper <path-to-pdf>`.
- `tikz` — TikZ collision-audit tool. Invoke via `/tikz [path/to/file.tex]` to find and fix visual collisions (label-on-arrow, boundary overlaps, crossing arrows) using mathematical gap calculations rather than eyeballing. Adapted from [MixtapeTools](https://github.com/scunning1975/MixtapeTools).

Use `./.claude/refresh-skills.sh` to pull fresh versions of upstream-sourced skills (currently: `humanizer`).

### Active profile-specific rules

- `writing-quality.md` (from info), `citation-discipline.md` + `reading-before-editing.md` (from research).
- `latex-bibtex-discipline.md` — LaTeX and bibliography conventions.
- `humanize-prose.md` — how to use the humanizer skill in the paper workflow.
- `tikz-prevention.md` — 6-rule protocol to prevent common TikZ failure modes (collisions, asymmetric scaling, missing edge labels).
- `tikz-library-bundle.md` — canonical preamble and specialty packages (`tikz-cd`, `pgfplots`, `circuitikz`, `forest`).

### TikZ figures

Canonical diagram starting points live at `.claude/rules/tikz-snippets/`:

- `flowchart.tex`, `tree.tex`, `graph.tex`, `plot.tex`, `block-diagram.tex`

Workflow: copy nearest snippet → edit → compile standalone → `\input{}` into paper. See `tikz-snippets/README.md` for details.

### Peer-review workflow (adopted from pedrohcgs/claude-code-my-workflow, MIT)

**Anti-hallucination:**
- `/verify-claims` — runs Chain-of-Verification in a forked subagent (`claim-verifier`) that never sees the draft. Reports claims as supported / contradicted / unverifiable.
- `rules/post-flight-verification.md` — verification discipline rule.

**Manuscript review:**
- `/review-paper` — single-pass or adversarial review modes.
- `/seven-pass-review` — 7 forked lenses (abstract, intro, methods, results, robustness, prose, citations) in parallel, then synthesized.
- `agents/editor.md` + `agents/methods-referee.md` + `agents/domain-referee.md` — peer-review simulation (populate `templates/journal-profile-template.md` with your target venues).

**Bibliography + figures:**
- `/validate-bib` — structural + semantic bib validation (missing/unused/DOI/drift).
- `/audit-reproducibility` — cross-check numeric claims against code outputs.
- `rules/cross-artifact-review.md` — auto-invoke code review when paper references scripts.

**Editing:**
- `/proofread` + `agents/proofreader.md` — three-phase propose → approve → apply editorial discipline.
- `rules/proofreading-protocol.md` — the discipline rule.

**Revise-resubmit:**
- `/respond-to-referees` — generate structured response-to-referees from a referee report + the revised manuscript.

**Templates:**
- `templates/requirements-spec.md` — MUST/SHOULD/MAY + CLEAR/ASSUMED/BLOCKED spec format.
- `templates/constitutional-governance.md` — non-negotiables vs preferences scaffold.
- `templates/journal-profile-template.md` — fill in per-venue for `/review-paper --peer`.

**Hooks (opt-in, configure in your `.claude/settings.local.json`):**
- `hooks/notify.sh` — cross-platform desktop notification on session events.
- `hooks/log-reminder.py` — stop-hook reminder to update session log.
- `hooks/verify-reminder.py` — post-Edit reminder to compile/verify academic files.
