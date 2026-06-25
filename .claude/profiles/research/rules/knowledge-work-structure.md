# Knowledge-work directory structure

All work in this repository is organized into a small set of top-level directories. Create each directory the first time you need to write into it (lazy creation — don't scaffold empty directories up front). Use this layout for every kind of knowledge work in the repo.

## The directories

- **`research/`** — All research output you produce, whether directly, via subagents, or via workflows. This is where findings, literature notes, source summaries, and analysis land. Use subdirectories when the structure is justified (e.g. by topic, source type, or phase) — not by default.
- **`papers/`** — Research papers you download during the work (PDFs and their extracted text). Distinct from `input/`: `papers/` holds sources *you* fetched while researching; `input/` holds documents *the user* gave you. Maintain a navigable index here — see "Paper index" below.
- **`input/`** — Raw input documents the user provides. This is the raw-data zone: uploaded PDFs, briefs, datasets, transcripts. Treat its contents as source material, not as something to edit in place.
- **`insights/`** — Insights formed jointly with the user while working. Distinct from `research/`: research is what you gathered, insights are what you concluded together. One file per insight (or per theme) keeps them citable.
- **`deliverables/`** — Dedicated documents produced for the user or for external people. Anything meant to leave the working session — reports, memos, slide outlines, response letters — belongs here, not mixed in with research notes.
- **`questions/`** — Open questions that arise during the work, especially when multiple experts or distinct specializations are involved. **Keep these as living documents:** record the question, fill in the answer as it becomes known, and revise an answer when something changes. Do not let them go stale — when a decision or finding invalidates a recorded answer, update it.

## Paper index

Whenever you download a research paper into `papers/`, keep a navigation index up to date so the collection stays browsable as it grows. Maintain `papers/INDEX.md` with one row per paper:

- **filename** in `papers/` (link to it)
- **title**
- **authors** (et al. is fine)
- **year** / **venue**
- **DOI or URL**
- **one-line relevance** — why this paper is in the project

Add an entry every time you add a paper; correct an entry if you later learn its metadata was wrong. The index is the map; the PDFs are the territory. If the collection grows large enough that one flat index is unwieldy, group papers into subdirectories of `papers/` by theme and keep a per-subdirectory index plus a top-level `papers/INDEX.md` that links to them.

## Why this matters

This separation keeps raw input, downloaded sources, gathered research, jointly-formed conclusions, and external-facing deliverables from bleeding into each other. It also makes the work auditable: anyone (including a future session) can see what came in, what you fetched, what was found, what was concluded, what was shipped, and what's still open.

## Defaults

- When the user hands you a document to work from → `input/`.
- When you download a research paper → `papers/`, and update `papers/INDEX.md`.
- When you or a subagent produce research output → `research/`.
- When you and the user reach a conclusion worth keeping → `insights/`.
- When you're asked to produce a document for the user or someone else → `deliverables/`.
- When you hit an open question (particularly one needing a specific expert) → `questions/`, and keep its answer current as the project evolves.
