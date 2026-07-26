<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Robust PDF Processing

**Default: read the PDF directly.** The Read tool reads PDFs natively — pass a `pages` range (e.g. `pages: "1-20"`) for documents longer than ~10 pages, up to 20 pages per request — and a large context window comfortably holds a full paper. You do **not** need to pre-split a normal document into chunk files.

## The Workflow

**Step 1: Check size first**

```bash
pdfinfo document.pdf | grep "Pages:"
ls -lh document.pdf
```

**Step 2: Read it directly**

- **Normal documents (up to ~100 pages):** read with the Read tool, using the `pages` parameter to page through (up to 20 pages per request). No pre-splitting needed.
- **Selective deep reading (a cost optimization, not a capacity limit):** for a long document you may scan section by section and read the load-bearing parts (methods, results, the sections your task actually depends on) in detail while skimming appendices and references. This saves tokens — not because the model cannot hold the document.

**Step 3 (fallback): split only when a direct read fails.** Reach for Ghostscript page-range splitting ONLY when the PDF is genuinely oversized (a book or high-resolution scan, hundreds of pages), corrupt, or a direct Read errors:

```bash
mkdir -p document/
for i in {0..9}; do
  start=$((i*5 + 1)); end=$(((i+1)*5))
  gs -sDEVICE=pdfwrite -dNOPAUSE -dBATCH -dSAFER \
     -dFirstPage=$start -dLastPage=$end \
     -sOutputFile="document/document_p$(printf '%03d' $start)-$(printf '%03d' $end).pdf" \
     document.pdf 2>/dev/null
done
```

Then read the page-range files one at a time, building understanding progressively.

## Error Handling Protocol

**If a direct read fails** (corrupt or oversized): fall back to Step 3 page-range splitting.

**If a chunk fails to process:**

1. Note the problematic chunk (e.g., "Chunk p021-025 failed").
2. Try splitting into 1–2 page pieces.
3. If still failing, skip it and document the gap.

**If splitting fails:**

1. Check if Ghostscript is installed: `gs --version`.
2. Try an alternative: `pdftk document.pdf burst output document_%03d.pdf`.
3. If all else fails, ask the user to provide specific page ranges manually.

## Where PDFs live

Per `knowledge-work-structure.md`: papers you download during research go in `papers/` (with an entry in `papers/INDEX.md`); documents the user provides go in `input/`.
