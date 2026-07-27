<!-- Profile: research -->

## Profile: research

Information + technical research — reading documentation, analyzing code, evaluating tools. Layers on `info`. No code writing.

**Where work lands.** Six lazily-created top-level directories: `research/` (findings), `papers/` (PDFs you fetched, plus `INDEX.md`), `input/` (what the user gave you), `insights/` (joint conclusions), `deliverables/` (external-facing output), `questions/` (open, living). Full contract in `.claude/rules/knowledge-work-structure.md`.

**Scholar Gateway** is a claude.ai-hosted connector, not a local MCP server: enable it in your claude.ai account settings, then confirm with `/mcp`. It indexes **journals only** (Wiley; ~8M articles) — **no conference proceedings** (IEEE, ACM, Springer LNCS, NeurIPS) and **no preprints**. Always supplement with DBLP, arXiv, and WebSearch.

**Auto-memory does not reach subagents** (except forks). Referee and verifier agents never see project memory — put anything they need in their prompt or in a committed file.
