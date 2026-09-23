---
paths:
  - "**/*.pdf"
  - "papers/**"
  - "input/**"
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Robust PDF Processing

**Default: read the PDF directly.** Read handles PDFs natively — pass a `pages` range, up to 20 pages per request — and the context window holds a full paper. Do not pre-split a normal document.

Ghostscript page-range splitting (`-dFirstPage` / `-dLastPage`) is for oversized or corrupt files only, after a direct read errors.

Scanned PDFs get no OCR from Read. Run `docling` (via `uvx`, pinned) or `ocrmypdf` first, keeping the output a PDF so page citations still resolve.

Papers you download go in `papers/` with an `INDEX.md` entry; user-provided documents go in `input/`.

## Many documents is a different problem from one

The guidance above is for **one** paper. It does not scale by multiplication: loading ~10 large PDFs in one session has repeatedly ended in `Prompt is too long` after partial work was already done.

For a task spanning more than two or three documents, decide up front to use **one subagent per document**:

1. Spawn one **fresh** subagent per document (a named or general-purpose subagent — not the `fork` type, which starts with this whole conversation already loaded).
2. Each reads only its own file and writes a short, fixed-shape note to disk (about 300 words).
3. Each returns only the note's path.
4. The main session reads only the notes and synthesizes.

Check the count against disk before starting: "my papers" that turns out to be eleven files is a different task from four.
