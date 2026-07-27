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
