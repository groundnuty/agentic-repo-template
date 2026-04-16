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
