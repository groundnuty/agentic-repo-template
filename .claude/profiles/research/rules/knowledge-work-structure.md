# Knowledge-work directory structure

Six top-level directories hold the work. Create each one the first time you need to write into it — lazy creation, no empty scaffolding.

- **`research/`** — what you gathered: findings, literature notes, source summaries, analysis. Subdivide only when the structure is justified.
- **`papers/`** — research papers *you* fetched while working (PDFs and extracted text), plus `INDEX.md`.
- **`input/`** — raw documents *the user* gave you: uploads, briefs, datasets, transcripts. Source material, not something to edit in place.
- **`insights/`** — what you and the user concluded together. One file per insight or theme keeps them citable.
- **`deliverables/`** — documents produced for the user or for external readers. Anything meant to leave the session.
- **`questions/`** — open questions, especially where distinct expertise is needed. Living documents: record the question, fill in the answer as it becomes known, revise when something invalidates it.

**Capture conclusions in `insights/` and open questions in `questions/` as they happen in a working session — decisions that stay in the transcript evaporate.**

## Paper index

Keep `papers/INDEX.md` current with one row per paper: **filename** (linked), **title**, **authors**, **year** / **venue**, **DOI or URL**, and a **one-line relevance** note saying why it is in the project. Add the entry when you add the paper; correct it if you later learn the metadata was wrong. If the collection outgrows one flat index, group `papers/` into themed subdirectories with a per-directory index and a top-level `INDEX.md` linking to them.

## Deliverables and artifacts

`deliverables/` markdown is the portable authority. Render a deliverable as a claude.ai Artifact when the reader benefits from layout or interactivity; the artifact's source file stays under `deliverables/`. Artifacts are platform-gated (unavailable on Bedrock, Vertex, and API-key sessions) — never make one the only copy.

## Why

The separation keeps raw input, fetched sources, gathered research, joint conclusions, and external-facing output from bleeding into each other, and makes the work auditable: a future session can see what came in, what you fetched, what was found, what was concluded, what shipped, and what is still open.
