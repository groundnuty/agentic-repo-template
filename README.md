# agentic-repo-template

A GitHub template repository with sane Claude Code defaults for autonomous work. Five profiles (`info` / `research` / `paper` / `paper-latex` / `code`) cover knowledge work, technical research, academic paper writing, LaTeX/TikZ manuscripts, and code-centric development.

## Quick start

1. On GitHub, click **Use this template → Create a new repository**.
2. Clone your new repo locally.
3. Pick a profile and run the init script:

```bash
./.claude/init.sh info         # knowledge / prose work only
./.claude/init.sh research     # technical research, doc reading
./.claude/init.sh paper        # paper / manuscript writing (format-agnostic)
./.claude/init.sh paper-latex  # paper + LaTeX / BibTeX / TikZ layer
./.claude/init.sh code         # code-centric projects
```

The script merges the profile's overlay into `.claude/settings.json`, copies profile-specific rules into `.claude/rules/`, appends profile guidance to `.claude/CLAUDE.md`, vendors profile-specific skills into `.claude/skills/`, then removes `.claude/profiles/` and `.claude/init.sh` themselves. Your repo ends up with only the final configuration.

### Bootstrap into an existing directory

"Use this template" is for new GitHub repos. To drop the template into an **existing** directory — local or remote, empty or with content, git repo or not — use `bootstrap.sh`. It fetches `.claude/` (and `.gitignore` if you don't have one) from the latest release into the current directory and runs `init.sh` for you, in one command.

Recommended (inspect-first) two-step:

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh -o /tmp/arp-bootstrap.sh
bash /tmp/arp-bootstrap.sh research        # or any profile, plus init.sh flags
```

Convenience one-liner (auto-executes remote code — use only if you trust the source):

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh | bash -s -- research
```

Options: `--ref vX.Y.Z` pins a version (default `main` = latest release); `--force` overlays even if a `.claude/` already exists (otherwise bootstrap refuses, to avoid clobbering a configured repo); `--cloud-compat` / `--strict-sandbox` / `--dry-run` pass through to `init.sh`.

## Profiles at a glance

| Profile | Primary use | Extends |
|---|---|---|
| `info` | reports, document analysis, prose | (base) |
| `research` | technical research, doc reading, no code writing | `info` |
| `paper` | paper / manuscript writing (format-agnostic — LaTeX, Markdown, Word, Google Docs) | `research` |
| `paper-latex` | LaTeX / BibTeX / TikZ layer on top of `paper` | `paper` |
| `code` | code-centric projects | `info` (not `research`) |

## Profile contents matrix

Every artifact by exact name, one row per item. Cell `✓` means the artifact is present in that profile after running `init.sh`. Items are grouped by surface (plugins / rules / skills / agents / hooks / templates) and within each surface ordered by commonality — items present in all five profiles come first, then items in fewer.

### Post-init totals

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 9 | 1 | — | — | 4 |
| `research` | 9 | 13 | 1 | — | — | 4 |
| `paper` | 9 | 17 | 9 | 5 | 2 | 5 |
| `paper-latex` | 9 | 21 | 11 | 5 | 3 | 5 |
| `code` | 9 | 13 | 1 | — | — | 4 |

### What's common vs specific at a glance

- **In all five profiles** (base + info): 8 plugins, 9 rules, 1 skill, 4 templates.
- **In four profiles** (`research` + `paper` + `paper-latex` + `code` — *not* `info`): 1 plugin (`context7`).
- **In three profiles** (`research` + `paper` + `paper-latex`): 4 rules (`citation-discipline`, `reading-before-editing`, `pdf-processing`, `knowledge-work-structure`).
- **In `paper` and `paper-latex`**: 4 rules (`humanize-prose`, `post-flight-verification`, `proofreading-protocol`, `cross-artifact-review`), 8 skills, 5 agents, 2 hooks, 1 template.
- **`paper-latex`-only** (LaTeX/TikZ layer on top of `paper`): 4 rules (`latex-bibtex-discipline`, `tikz-prevention`, `tikz-library-bundle`, `tikz-snippets/`), 2 skills (`tikz`, `validate-bib`), 1 hook (`verify-reminder.py`).
- **Code-only**: 4 rules.

### Plugins (9 unique, `context7` conditional)

| Plugin | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `superpowers@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `commit-commands@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `claude-md-management@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-report@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hookify@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `claude-code-setup@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `feature-dev@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `elements-of-style@superpowers-marketplace` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `context7@claude-plugins-official` | — | ✓ | ✓ | ✓ | ✓ |

### Rules (25 unique)

| Rule | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `autonomous-work.md` — how to behave unattended | ✓ | ✓ | ✓ | ✓ | ✓ |
| `pr-discipline.md` — commit/PR format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `project-conventions.md` — per-project overrides (stub) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `writing-quality.md` — prose conventions, banned AI-isms | ✓ | ✓ | ✓ | ✓ | ✓ |
| `summary-parity.md` — don't surgical-patch drifting summaries | ✓ | ✓ | ✓ | ✓ | ✓ |
| `exploration-fast-track.md` — 60/100 threshold for experiments | ✓ | ✓ | ✓ | ✓ | ✓ |
| `exploration-folder-protocol.md` — `explorations/` lifecycle | ✓ | ✓ | ✓ | ✓ | ✓ |
| `meta-governance.md` — template vs working project, 2-tier memory | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-logging.md` — three-trigger logging discipline | ✓ | ✓ | ✓ | ✓ | ✓ |
| `citation-discipline.md` — never cite from memory | — | ✓ | ✓ | ✓ | — |
| `reading-before-editing.md` — full read before research edits | — | ✓ | ✓ | ✓ | — |
| `pdf-processing.md` — safe large-PDF chunked workflow | — | ✓ | ✓ | ✓ | — |
| `knowledge-work-structure.md` — research/papers/input/insights/deliverables/questions layout | — | ✓ | ✓ | ✓ | — |
| `humanize-prose.md` — how to use the humanizer skill | — | — | ✓ | ✓ | — |
| `post-flight-verification.md` — Chain-of-Verification discipline | — | — | ✓ | ✓ | — |
| `proofreading-protocol.md` — three-phase propose → approve → apply | — | — | ✓ | ✓ | — |
| `cross-artifact-review.md` — paper review auto-invokes code review | — | — | ✓ | ✓ | — |
| `latex-bibtex-discipline.md` — LaTeX + BibTeX conventions | — | — | — | ✓ | — |
| `tikz-prevention.md` — 6-rule protocol for safe TikZ | — | — | — | ✓ | — |
| `tikz-library-bundle.md` — canonical preamble + specialty packages | — | — | — | ✓ | — |
| `tikz-snippets/` — 5 compilable standalone figures + README | — | — | — | ✓ | — |
| `makefile-conventions.md` — standard Make targets | — | — | — | — | ✓ |
| `devbox-usage.md` — devbox idioms and CI parity | — | — | — | — | ✓ |
| `testing-discipline.md` — TDD, 80% coverage, isolation | — | — | — | — | ✓ |
| `verification-before-done.md` — "am I actually done?" gate | — | — | — | — | ✓ |

### Skills (11 unique; invoke via `/<name>`)

| Skill | Source | info | research | paper | paper-latex | code |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `permission-check` | pedrohcgs | ✓ | ✓ | ✓ | ✓ | ✓ |
| `humanizer` | [groundnuty/humanizer](https://github.com/groundnuty/humanizer) (git upstream, refreshable) | — | — | ✓ | ✓ | — |
| `analyze-paper` | local (generalized from a ccgrid2026 paper repo) | — | — | ✓ | ✓ | — |
| `verify-claims` | [pedrohcgs](https://github.com/pedrohcgs/claude-code-my-workflow) — CoVe via forked subagent | — | — | ✓ | ✓ | — |
| `respond-to-referees` | pedrohcgs — R&R response letter generator | — | — | ✓ | ✓ | — |
| `seven-pass-review` | pedrohcgs — 7 parallel forked review lenses | — | — | ✓ | ✓ | — |
| `proofread` | pedrohcgs — three-phase editorial pass | — | — | ✓ | ✓ | — |
| `review-paper` | pedrohcgs — single-pass + adversarial modes | — | — | ✓ | ✓ | — |
| `audit-reproducibility` | pedrohcgs — cross-check numeric claims against code | — | — | ✓ | ✓ | — |
| `tikz` | [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) — 6-pass collision audit | — | — | — | ✓ | — |
| `validate-bib` | pedrohcgs — structural + semantic bib validation | — | — | — | ✓ | — |

### Agents (5 unique — `paper` and `paper-latex` only)

Dispatched via `Task`/`Agent` subagents, not directly by the user. Format-agnostic (referee review lenses apply to any manuscript), so both `paper` and `paper-latex` ship them.

| Agent | Source | info | research | paper | paper-latex | code |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `claim-verifier.md` | pedrohcgs — fresh-context CoVe verifier | — | — | ✓ | ✓ | — |
| `proofreader.md` | pedrohcgs — grammar/typo/overflow review | — | — | ✓ | ✓ | — |
| `editor.md` | pedrohcgs — desk review + picks 2 disagreeing referees | — | — | ✓ | ✓ | — |
| `methods-referee.md` | pedrohcgs — methods/rigor review | — | — | ✓ | ✓ | — |
| `domain-referee.md` | pedrohcgs — substantive review with disposition | — | — | ✓ | ✓ | — |

### Hooks (3 unique — opt-in, reference from `settings.local.json` to enable)

| Hook | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `notify.sh` — cross-platform desktop notification on session events | — | — | ✓ | ✓ | — |
| `log-reminder.py` — stop-hook reminder to update session log | — | — | ✓ | ✓ | — |
| `verify-reminder.py` — post-Edit reminder to compile/verify `.tex`/`.bib` files | — | — | — | ✓ | — |

### Templates (5 unique)

| Template | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `requirements-spec.md` — MUST/SHOULD/MAY + CLEAR/ASSUMED/BLOCKED format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `constitutional-governance.md` — non-negotiables vs preferences | ✓ | ✓ | ✓ | ✓ | ✓ |
| `exploration-readme.md` — `explorations/` sandbox README | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-log.md` — session-log format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `journal-profile-template.md` — per-venue review calibration | — | — | ✓ | ✓ | — |

### External requirements (documented, not shipped)

| Requirement | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| Scholar Gateway (claude.ai connector — enable once in account) | — | required | required | required | — |
| `jq` installed (init script dependency) | required | required | required | required | required |
| `git` installed (for `refresh-skills.sh`) | — | — | required | required | — |
| LaTeX distribution (`pdflatex`/`lualatex`/`xelatex` + `bibtex`) | — | — | — | required | — |
| devbox installed (recommended) | — | — | — | — | recommended |
| `/configure-ecc` run (for language-specific skills) | — | — | — | — | recommended |

### Attribution

The `paper` and `paper-latex` profiles adopt 17 pieces from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT). `paper-latex` also vendors 1 piece from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) (use freely, attribution appreciated). Both profiles vendor [groundnuty/humanizer](https://github.com/groundnuty/humanizer) (git-upstream-sourced, refreshable via `refresh-skills.sh`). Each vendored file carries an inline attribution header.

## Requirements

- [Claude Code](https://claude.com/claude-code) v2.1.113 or later (for Opus 4.7 support, sandbox-bypass fix, and exec-wrapper deny coverage) (needed for `PreCompact` hook with `$CLAUDE_TRANSCRIPT_PATH`, `ConfigChange` hook, `sandbox.failIfUnavailable`).
- `jq` on your `$PATH` (for the init script's deep-merge).
- `git` on your `$PATH` (for the paper profiles' upstream-sourced skill refresh; optional otherwise).
- **Scholar Gateway** claude.ai connector — enable in claude.ai account settings if using `research`, `paper`, or `paper-latex` profiles.
- A **LaTeX distribution** (`pdflatex`/`lualatex`/`xelatex` + `bibtex`) if using `paper-latex`.

## What's in the template

### Base `.claude/` (shipped to every profile)

- `settings.json` — permissions (wildcard allow with bare tool names + deny list with `Edit(...)` rules for sensitive paths — `Edit(path)` covers all file-editing tools incl. `Write`/`NotebookEdit` per Claude Code v2.1.210+), sandbox (OS-level enforcement, cloud-safe by default — `enableWeakerNestedSandbox: true`, no `failIfUnavailable`; opt into the hard gate with `init.sh --strict-sandbox`), plugins (8 baseline), hooks (SessionStart / ConfigChange / PreCompact / SessionEnd), env (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `ENABLE_LSP_TOOL=1`), `effortLevel: xhigh` + `verbose: true` tuned for agentic work.
- `CLAUDE.md` — project-conventions stub. Each profile appends a `CLAUDE.append.md` overview on init.
- `rules/` — three base rules: `autonomous-work.md`, `pr-discipline.md`, `project-conventions.md`.
- `audit.log` — committed to git; `ConfigChange` hook appends a line on every `.claude/*` modification.
- `session-reports/` — session transcripts and git-state snapshots from `PreCompact` / `SessionEnd` hooks.
- `commands/template-check.md` — `/template-check` slash command; see [Upgrading](#upgrading).

### Post-init leftovers

- `refresh-skills.sh` — re-fetch upstream-sourced skills (currently: `humanizer` in the paper profile).
- `.template-version` — stamp recording which template `version` / `profile` was applied and `applied_at` timestamp. Used by `/template-check`.
- `bootstrap.sh` (root-level) — one-command initializer for dropping the template into an existing directory; see [Bootstrap into an existing directory](#bootstrap-into-an-existing-directory). `init.sh` removes it from a repo it initializes (it's tooling for setting up *other* directories, not project content).

### Escape hatch

- `~/.claude/settings.local.json` or `.claude/settings.local.json` (gitignored) — merge with base at load time. Per-project `allow`/`ask`/`deny` overrides and hook activations live here.

## Versioning and release model

This is the **release artifact** repo. Development happens in the sibling [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private) — this repo is what "Use this template" consumes and is always release-ready.

- **`main`** is always the **latest stable release**. Every commit merged here has passed the test suite in the research repo.
- **Git tags** (`v0.1.0`, `v0.1.1`, …) are addressable snapshots — useful if you want to pin a specific version.
- **GitHub Releases** (visible at the repo's [Releases](https://github.com/groundnuty/agentic-repo-template/releases) page) correspond 1:1 with tags and carry release notes.
- **[CHANGELOG.md](./CHANGELOG.md)** — user-facing release notes per version.

### "Use this template" gives you `main @ HEAD` (= latest release)

GitHub's "Use this template" button always copies from the default branch at HEAD. It does not offer tag selection. So:

- Click the button → you get the latest stable version.
- Need an older version? Clone, then `git checkout v0.1.4` (or whichever tag) before running `init.sh`.

### Semantic versioning policy

Currently `v0.1.x` (pre-stable). Minor bumps are additive; breaking changes go in CHANGELOG as **BREAKING**.

Post-`v1.0.0`:
- **MAJOR** — breaking changes (removed plugin, changed `init.sh` CLI, changed `settings.json` schema requirements).
- **MINOR** — new profile, new plugin added to baseline, new rule shipped.
- **PATCH** — documentation fixes, small rule-content adjustments, refreshed vendored skills.

## Upgrading

Every `init.sh` run stamps `.claude/.template-version` with the version, profile, and timestamp that were applied. This is how you (or Claude) can tell later which version a given repo is tied to.

### Checking for updates

From inside a repo initialized from this template, run the `/template-check` slash command:

```
/template-check
```

Claude reads the stamp, fetches the latest release tag from [the template repo's GitHub API](https://api.github.com/repos/groundnuty/agentic-repo-template/releases/latest), and prints one of:

- **Up to date** — nothing to do.
- **Behind** — shows the CHANGELOG entries between your stamp and the latest tag.
- **No network** — can't reach `api.github.com`; prints your stamp and stops.
- **No stamp** — this repo predates v0.1.9 or wasn't initialized via `init.sh`; prints instructions for creating a stamp by hand.

### Applying an update (manual)

There's no automated upgrade path — user-owned files (`CLAUDE.md`, `.claude/rules/project-conventions.md`) can't be safely merged without human review. Manual flow:

```bash
# 1. Clone the latest template elsewhere, check out the target tag.
git clone https://github.com/groundnuty/agentic-repo-template.git /tmp/arp-latest
git -C /tmp/arp-latest checkout v0.1.9   # or whichever tag

# 2. Diff against your repo's .claude/ to see what changed.
diff -r /tmp/arp-latest/.claude .claude | less

# 3. Cherry-pick what you want. Likely candidates:
#    - settings.json deny-list expansions
#    - new rules in rules/
#    - updated rule content
#    Unlikely candidates (already user-owned):
#    - CLAUDE.md (root)
#    - rules/project-conventions.md
```

After updating, re-stamp `.claude/.template-version` to reflect the new version:

```bash
sed -i '' "s/^version=.*/version=v0.1.9/" .claude/.template-version   # macOS
# or on Linux:  sed -i "s/^version=.*/version=v0.1.9/" .claude/.template-version
```

An automated `/template-upgrade` command that handles the diff/merge is tracked for v0.2.x; for now, manual review is the safer default.

### Sandbox modes (v0.1.15+)

The base `settings.json` is **cloud-safe by default** as of v0.1.15. Repos created from this template open cleanly in [claude.ai/code](https://claude.ai/code)'s nested-container sandbox without any flag, and run normally on local Linux/macOS too. No `--cloud-compat` needed for new repos.

If you need the strict managed-deployment behavior (Claude Code aborts session-start when the OS sandbox can't initialize), pass `--strict-sandbox` at init time:

```bash
./.claude/init.sh code --strict-sandbox    # opts into sandbox.failIfUnavailable=true
```

**What changed in v0.1.15** vs. v0.1.14:

- `sandbox.failIfUnavailable` is no longer in base settings (defaults to `false`: warn + run unsandboxed when OS sandbox isn't available).
- `sandbox.enableWeakerNestedSandbox: true` is now in base (no-op for normal local sandbox; lets the sandbox initialize on cloud/nested-container VMs).
- `--cloud-compat` is **deprecated** (still works, prints a warning) — it's a no-op for the failIfUnavailable patch since the base is already cloud-safe. It still prunes devbox/nix paths from `allowWrite`, which is cosmetic on cloud VMs (those paths just don't exist) and harmless on local.

**Migrating an existing repo to v0.1.15:**

- **From v0.1.14 with `--cloud-compat` already applied:** no action needed; just bump the stamp's `version=` to `v0.1.15`.
- **From v0.1.14 or earlier without `--cloud-compat`:** open the repo in Claude Code locally (where the strict sandbox isn't a problem) and apply the patches by hand or via:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/v0.1.15/.claude/init.sh -o /tmp/init-v15.sh
  bash /tmp/init-v15.sh --cloud-compat   # still works in v0.1.15 (deprecated alias)
  ```

Why the inversion: v0.1.14's `--cloud-compat` flag worked for users with shell access who could run `init.sh`. But it broke the natural Web-first workflow — "Use this template" → open the new repo on claude.ai/code → ask the agent to init it. The un-inited template's `failIfUnavailable: true` aborted session-start before any agent came online. v0.1.15 fixes that root cause: the common case (works everywhere) is the default; strict sandboxing is the explicit opt-in.

---

## Updating the template or debating decisions

All design research, empirical data, and decision rationale live in a companion repo: [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research) (private). Before changing the template, read the research there.

## License

MIT. See `LICENSE`.
