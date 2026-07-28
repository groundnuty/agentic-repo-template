<!-- Profile: paper-latex -->

## Profile: paper-latex

LaTeX + BibTeX + TikZ layer on top of `paper`. Apply when the manuscript is compiled with LaTeX and figures are authored in TikZ. Everything here is additive — the `paper` workflow is unchanged. The LaTeX skills (`/agentic-paper:tikz`, `/agentic-paper:validate-bib`) and the texlab LSP config ride in the same `agentic-paper` plugin the `paper` profile declares; this tier adds only the path-scoped rules below.

**Compile discipline** lives in `.claude/rules/latex-bibtex-discipline.md`, which is path-scoped: it loads when you touch a `.tex` or `.bib` file, not on every session. Read it before editing either.

**Start TikZ figures from a snippet,** never from scratch — the five canonical starters (`flowchart`, `tree`, `graph`, `plot`, `block-diagram`) ship with the `/agentic-paper:tikz` snippets, under `${CLAUDE_PLUGIN_ROOT}/skills/tikz/snippets/`. Copy the nearest one, compile it standalone, then `\input{}` it into the manuscript.

**Opt-in hook:** `hooks/verify-reminder.py` — post-Edit reminder to recompile `.tex`/`.bib`. Enable by referencing it in `.claude/settings.local.json`.
