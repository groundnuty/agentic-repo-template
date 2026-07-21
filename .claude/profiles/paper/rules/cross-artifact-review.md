<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Cross-Artifact Review Protocol

A paper is not an island. Its claims depend on the code that produced them. Reviewing the paper without reviewing the code is reviewing half the artifact.

## The Dependency Graph

```
manuscript.tex ──cites──> Table 2
Table 2        ──from──> scripts/_outputs/results.*
results.*      ──by──> scripts/03_analyze.*
03_analyze.*   ──uses──> scripts/_outputs/clean.*
clean.*        ──by──> scripts/02_clean.*
02_clean.*     ──reads──> data/raw.csv
```

A bug in `02_clean` invalidates Table 2. Reviewing `manuscript.tex` without touching the code misses this class of error entirely.

## When to apply

Applies when `/review-paper` runs on a manuscript that references analysis scripts. Detection is **pattern-based** — if the manuscript has none of the signals below, no cross-artifact work happens (and `--no-cross-artifact` is a no-op).

Detection signals:

- `\input{scripts/...}` or `\input{tables/...}`
- `%% source: scripts/03_analyze.R` (or `.py`, `.do`, `.jl`, …) comments
- Numeric claims in text (estimates, coefficients, N, p-values) **combined with** a sibling `scripts/` directory (R, Python, Stata, Julia, …)
- Table labels in the paper that match filenames under `scripts/**/_outputs/`

Detection is intentionally conservative — a theory paper with no code should not trigger the protocol, even if it lives in a repo that has scripts for other work.

## The protocol

When `/review-paper` detects any of the above:

### 1. Identify referenced scripts

Scan the manuscript for `\input{path}` commands, `%% from: scripts/...` line comments, and table labels that match filenames in `scripts/**/_outputs/`. Build a list of scripts that produced content in this paper.

### 2. Review the referenced scripts

For each identified script, review it in a forked subagent (`context: fork`) — read it and verify it actually produces the claimed outputs, in whatever language it's written (R, Python, Stata, Julia, shell, …). This is a code review focused on correctness of the paper's numeric claims, not style. Save reports to `.claude/session-reports/cross_artifact_[paper]/review_[script].md`.

(This template does not ship a language-specific code-review skill. If you have added one for your stack — e.g. via `/configure-ecc` or a project subagent — invoke it here; otherwise do the review directly.)

### 3. Run `/audit-reproducibility`

Run `/audit-reproducibility $manuscript scripts/**/_outputs/` once. Save to `.claude/session-reports/cross_artifact_[paper]/reproducibility.md`.

### 4. Surface cross-artifact findings

In the paper review report, add a new section:

```markdown
## Cross-Artifact Findings

**Scripts reviewed:** N (see `.claude/session-reports/cross_artifact_[paper]/`)
**Reproducibility:** PASS / FAIL — k of m claims within tolerance
**Code quality:** C critical, M major, L minor

### Critical cross-artifact issues (paper + code together)
| Paper claim | Code location | Issue |
|---|---|---|

### Code-only issues (won't block paper, but file a follow-up)
…

### Paper-only issues (code is clean)
[Rest of the paper review goes here]
```

### 5. Exit behavior

- Any CRITICAL from `/audit-reproducibility` (FAIL on tolerance) → escalate to CRITICAL in paper review.
- Code CRITICAL bugs that affect paper claims → escalate in paper review.
- Code CRITICAL bugs unrelated to paper claims → file as separate action item.

## Opt-out

- `/review-paper --no-cross-artifact` skips the dependency graph. Useful for theory papers, comments, or preprints without code.

## Cross-references

- `.claude/skills/review-paper/SKILL.md` — the orchestrator.
- `.claude/skills/audit-reproducibility/SKILL.md` — numeric-claims verifier.

## What this rule does NOT require

- Running R / Stata / Python / Julia (that's `/audit-reproducibility`'s job, and it reads existing outputs).
- Git-blame archaeology — we review current state.
- Judging whether a paper's authors wrote good code vs. whether their *results* are defensible. We care about the latter first.

## `--peer` mode ordering

In `/review-paper --peer [journal]` mode, cross-artifact review runs **before** the editor's desk review (as Phase 0). This gives the editor reproducibility evidence — any FAIL on load-bearing claims is desk-reject-worthy. In default and `--adversarial` modes, cross-artifact still runs at Step 6b (after the paper review). Both orderings are valid.
