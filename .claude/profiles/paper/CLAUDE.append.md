<!-- Profile: paper -->

## Profile: paper

Academic paper writing — LaTeX/BibTeX, literature review, prose polishing, structured peer review.

### Scholar Gateway

Same one-time setup as the `research` profile. Scholar Gateway + Google Scholar WebSearch fallback both active for this profile.

### Vendored skills

This profile vendors two skills into `.claude/skills/`:
- `humanizer` — removes AI-writing patterns from prose. Invoke via `/humanizer`. Upstream: https://github.com/groundnuty/humanizer
- `analyze-paper` — structured analysis of a reference paper PDF. Invoke via `/analyze-paper <path-to-pdf>`.

Use `./.claude/refresh-skills.sh` to pull fresh versions of upstream-sourced skills (currently: `humanizer`).

### Active profile-specific rules

- `writing-quality.md` (from info), `citation-discipline.md` + `reading-before-editing.md` (from research).
- `latex-bibtex-discipline.md` — LaTeX and bibliography conventions.
- `humanize-prose.md` — how to use the humanizer skill in the paper workflow.
