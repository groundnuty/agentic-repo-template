# Citation discipline

Applied when producing research output (reports, analyses, literature reviews).

## Rules

1. **Never cite from memory.** Every citation must be traced to a URL or file that was accessed in this session.
2. **Verify before citing.** If a claim depends on source X, WebSearch or fetch X first. Paste the quoted passage into the notes.
3. **Prefer primary sources.** Link to the paper, not a blog post summarizing the paper.
4. **Include access date** for web sources (`accessed YYYY-MM-DD`).
5. **Format consistency.** Use one citation style across the document. If the host project has a `.bib` or `references.md`, extend it; do not start a new one.

## Search tools, in priority order

1. **`/deep-research <question>`** — the default entry for broad questions with unknown sources (native fan-out plus per-claim verification; unverifiable claims report as unverified).
2. **Scholar Gateway** (MCP) for journal papers in the indexed corpus.
3. **WebSearch** with `site:scholar.google.com` or `site:arxiv.org` for preprints and conference proceedings.
4. **WebFetch** of the specific paper URL when a reference is already known.

**WebSearch is capped at 200 calls per session**, counted across all subagents, and fails *silently* past the cap — budget your fan-outs.

**WebFetch is lossy** — a small model answers your prompt about the page rather than handing you the page. For verbatim quotes use the fetch MCP server (if enabled) or `curl`.

## When Scholar Gateway returns nothing

Do not assume no results means no relevant work. Try at least one of:
- Google Scholar via WebSearch.
- arXiv direct search.
- Search the project's existing bibliography for adjacent work.

## Pitfalls

- Hallucinated titles or authors: always verify the exact metadata before quoting.
- Circular citation: source A cites source B which cites source A. Dig back to the primary claim.
- Paywall dead-ends: if a paper is inaccessible, note it and move on rather than paraphrasing from the abstract alone.
