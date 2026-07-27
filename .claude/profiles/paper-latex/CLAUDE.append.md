<!-- Profile: paper-latex -->

## Profile: paper-latex

LaTeX + BibTeX + TikZ layer on top of `paper`. Apply when the manuscript is compiled with LaTeX and figures are authored in TikZ. Everything here is additive — the `paper` workflow is unchanged.

**Compile discipline** lives in `.claude/rules/latex-bibtex-discipline.md`, which is path-scoped: it loads when you touch a `.tex` or `.bib` file, not on every session. Read it before editing either.

**Start TikZ figures from a snippet,** never from scratch — copy the nearest of `.claude/rules/tikz-snippets/{flowchart,tree,graph,plot,block-diagram}.tex`, compile it standalone, then `\input{}` it into the manuscript.

**Opt-in hook:** `hooks/verify-reminder.py` — post-Edit reminder to recompile `.tex`/`.bib`. Enable by referencing it in `.claude/settings.local.json`.
