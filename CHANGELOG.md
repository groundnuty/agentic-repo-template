# Changelog

User-facing history of this template. Every version is a git tag with a matching GitHub Release; `main` is always the latest stable release.

Design rationale, empirical research, and decision history live in [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research).

---

## [v0.1.16] — 2026-06-10

Fix: every new Claude Code session on a template-initialized repo printed a `/doctor` warning that `permissions.allow["mcp__*"]` was rejected. Wildcarding the entire MCP namespace in allow rules is intentionally disallowed by Claude Code (security: prevents prompt-injection-via-MCP-response from auto-executing tools from arbitrary unknown servers). Allow rules must name a literal server prefix; wildcards are only legal in the tool position after `mcp__<server>__`.

### What changed

- **Dropped `"mcp__*"`** from base `.claude/settings.json` `permissions.allow`. Claude Code was already skipping the invalid rule — the only functional change is the `/doctor` warning goes away.
- **Added enumerated allow entries** for all claude.ai-hosted MCP connectors observed in use (15 servers): `mcp__claude_ai_{Gmail,PubMed,bioRxiv,Scholar_Gateway,Asana,Atlassian,Box,Canva,Consensus,Figma,HubSpot,Intercom,Linear,Notion,monday_com}__*`. These auto-allow without prompt — the connectors are user-account-controlled (you enable them in claude.ai settings), so trusting their tools matches user intent.
- **Added the context7 plugin MCP**: `mcp__plugin_context7_context7__*`. Matches `enabledPlugins["context7@claude-plugins-official"]` (which we ship in research / paper / paper-latex / code profiles since v0.1.15).
- **Added two built-in MCP introspection tools** as bare names: `ListMcpResourcesTool`, `ReadMcpResourceTool`. Read-only, safe.

### What stays unchanged

- **Custom and third-party MCP servers** are NOT pre-allowed. If you use them, add per-server entries to your gitignored `.claude/settings.local.json`:
  ```json
  {
    "permissions": {
      "allow": [
        "mcp__my_custom_server__*"
      ]
    }
  }
  ```
- **The `mcp__<server-wildcard>__*` shape is rejected** by Claude Code. You can't say "any MCP server" — must enumerate.

### Migration

Existing v0.1.x repos: edit `.claude/settings.json` and remove the line `"mcp__*",` from `permissions.allow`. Optionally add the enumerated list above. Or re-init from v0.1.16.

### Tests

10 new assertions in `tests/test-init.sh`: base has no `mcp__*`, no MCP allow entry wildcards the server name (regex guard), 6 spot-check connector entries present, both List/ReadMcpResourceTool present, plugin context7 MCP present. **154 tests total, all green.**

### Why Path A (enumerate) and not Path B (`--permission-mode bypassPermissions`)

Bypass-mode disables all permission gates including the deny list. D2 (32-repo survey + design) rejected that posture. Enumeration costs ~18 lines of allow list and stays within the security model.

---

## [v0.1.15] — 2026-05-31

**⚠ BREAKING** for managed-deployment users who relied on the default `sandbox.failIfUnavailable: true`. Everyone else: improvement, no action needed.

Fix the chicken-and-egg gap that v0.1.14 missed: opening a fresh "Use this template" repo on [claude.ai/code](https://claude.ai/code) before running `init.sh` aborted session-start because the base settings shipped `failIfUnavailable: true`. v0.1.14's `--cloud-compat` flag couldn't help — the flag only takes effect after `init.sh` runs, and the un-inited template can't start a session.

### What changed

- **Base `settings.json` is now cloud-safe.**
  - `sandbox.failIfUnavailable` removed (defaults to `false`: warn + run unsandboxed when OS sandbox is unavailable).
  - `sandbox.enableWeakerNestedSandbox: true` added (no-op for normal local sandbox; lets the sandbox initialize on cloud/nested-container VMs).
- **New `--strict-sandbox` flag.** Opt-in to the strict gate that v0.1.14 had as default. For managed deployments where sandboxing is a hard security requirement. Adds `sandbox.failIfUnavailable: true` and stamps `strict_sandbox=true`.
- **`--cloud-compat` is now deprecated.** Still works — prints a deprecation warning on stderr, still prunes devbox/nix paths from `allowWrite` (cosmetic), still stamps `cloud_compat=true`. Removed in a future v0.2.x major.
- **`context7` plugin marketplace name corrected** in `research` + `code` overlays. Was `context7@external-plugins` (orphan — no such marketplace declared), now `context7@claude-plugins-official` (matches the marketplace already declared in base). Context7 now **actually loads** in research / paper / paper-latex / code profiles. v0.1.14 D35 claimed the orphan was "removed" but only fixed base — profile overlays kept re-introducing it. This release closes that loop.
- **Stamp file format.** Adds `strict_sandbox=<true|false>` line. `cloud_compat=` line preserved for backward compat.

### Sandbox modes summary

| Mode | Flag | `sandbox.failIfUnavailable` | Use case |
|---|---|---|---|
| Default (v0.1.15+) | (none) | absent → defaults to `false` | Works on Claude Code Web + local. The common case. |
| Strict | `--strict-sandbox` | `true` | Managed deployments where sandbox is a hard gate. |
| Cloud-compat | `--cloud-compat` (deprecated) | absent (same as default) | Backward compat. Use the default instead. |

### Migration

| Existing repo state | What to do |
|---|---|
| v0.1.14 with `--cloud-compat` already applied | No action. Optionally bump stamp `version=v0.1.14` → `v0.1.15`. |
| v0.1.14 (or earlier) without `--cloud-compat`, **and Claude Code Web fails to open it** | Open it locally (where strict sandbox isn't a problem), then either re-run `init.sh <profile>` from a fresh v0.1.15 clone (clean migration) or hand-edit `.claude/settings.json` to remove `sandbox.failIfUnavailable` and add `"enableWeakerNestedSandbox": true`. |
| Want the strict gate (managed deployment) | Pass `--strict-sandbox` at init time. |
| Already using `context7` | Re-init or edit `.claude/settings.json`: change `context7@external-plugins` → `context7@claude-plugins-official`. The plugin will start loading instead of silently no-op-ing. |

### Tests

- 20 new assertions in `tests/test-init.sh`: base settings has no `failIfUnavailable`, base has `enableWeakerNestedSandbox: true`, profile overlays use the correct context7 marketplace name, `--strict-sandbox` sets `failIfUnavailable: true` and stamps correctly, `--cloud-compat` still works but prints deprecation warning, post-init context7 lands at `@claude-plugins-official` (not the orphan).
- **117 tests total, all green.**

### Why this is breaking — but only for one group

Managed deployments that relied on the default `failIfUnavailable: true` as a hard sandbox gate now need to pass `--strict-sandbox` explicitly. One-flag change in their deployment scripts. All other users: unaffected or strictly better.

### Honest disclosure

v0.1.14's `--cloud-compat` was a partial fix: it solved the case "I have shell access, can run `init.sh`" but missed "I created the repo from template on GitHub and opened it on the web". The chicken-and-egg was that the un-inited template's strict-by-default sandbox aborted session-start before any agent could run `init.sh`. v0.1.15 fixes the root cause by inverting the default. Discovered when a user hit it on `agentic-music-composer`.

---

## [v0.1.14] — 2026-05-17

Fix: repos initialized with the previous `failIfUnavailable: true` baseline crash on session start in Claude Code on the web. The web VM is itself a container, has no `bubblewrap`/`socat` pre-installed, and Ubuntu 24.04 AppArmor blocks unprivileged user namespaces — so the Linux sandbox can't initialize, and `failIfUnavailable: true` turns that into a hard session-start failure (per [Settings reference](https://code.claude.com/docs/en/settings#sandbox-settings): *"Exit with an error at startup if `sandbox.enabled` is true but the sandbox cannot start"*). Symptom: opening the repo on [claude.ai/code](https://claude.ai/code) produces a generic "error" and the session never starts.

### What changed

- **New `--cloud-compat` flag on `init.sh`.** Patches settings to be safe inside the web's nested-container sandbox. Patches applied:
  1. Remove `sandbox.failIfUnavailable` — defaults to `false`, meaning Claude Code warns once and runs commands unsandboxed when the OS sandbox can't initialize. This is the right behavior on the web VM, which is already isolation.
  2. Set `sandbox.enableWeakerNestedSandbox: true` — the documented escape hatch for unprivileged Docker / cloud-VM environments where bubblewrap can't create privileged namespaces.
  3. Prune `~/.nix-profile`, `/nix`, `~/.cache/devbox`, `~/.local/share/devbox` from `sandbox.filesystem.allowWrite` — these paths don't exist on the cloud VM, and bubblewrap would fail to bind-mount them if it did run. `~/.claude/projects` is retained (D31).
  4. Remove `context7@external-plugins` from `enabledPlugins` — orphan reference; no `external-plugins` marketplace is declared anywhere in base settings, so this entry has been a no-op (with a warning) on every install.
- **Two operating modes** for the new flag:
  - `./.claude/init.sh <profile> --cloud-compat` — fresh init that applies the profile chain and then the cloud patches. Use when creating a new repo that you intend to open on the web.
  - `./.claude/init.sh --cloud-compat` (no profile) — patch-only mode for an already-initialized repo. Re-fetch `init.sh` from this release, drop it into `.claude/`, run with the flag, done. The original profile chain isn't re-applied, so user edits to rules/skills/CLAUDE.md are untouched.
- **Stamp file gains `cloud_compat=<true|false>` line.** `/template-check` can now see whether a repo has been patched.

### What did NOT change

- **Default behavior is unchanged.** Without `--cloud-compat`, init.sh produces the same output as v0.1.13. `failIfUnavailable: true` is still the baseline for local-only repos that want a hard sandbox gate.
- **No rules, skills, hooks, or plugins were touched** (except removing the orphan context7 reference, which never worked anyway).

### Tests

26 new assertions in `tests/test-init.sh`:

- `research --cloud-compat`: exits 0, removes `failIfUnavailable`, sets `enableWeakerNestedSandbox: true`, prunes the four devbox/nix paths from `allowWrite`, retains `~/.claude/projects` (D31 guard), removes `context7@external-plugins`, plugin count is 8 not 9, stamp shows `cloud_compat=true`.
- Negative: `research` without `--cloud-compat` preserves `failIfUnavailable`, does NOT add `enableWeakerNestedSandbox`, retains `/nix`, stamp shows `cloud_compat=false`.
- Patch-only path: `init.sh --cloud-compat` on an already-initialized repo (where `profiles/` and the original `init.sh` are gone) applies all four patches, preserves the existing `profile=` line, flips `cloud_compat` to `true`.
- Patch-only with no `settings.json` exits 4 with an explanatory error.
- `--cloud-compat --dry-run` is a no-op (settings and stamp files unchanged).

123 tests total, all green.

### Migration

- **New repos for cloud use:** `./.claude/init.sh research --cloud-compat` (or whichever profile).
- **Existing repos crashing on the web:**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/v0.1.14/.claude/init.sh -o .claude/init.sh
  bash .claude/init.sh --cloud-compat
  rm .claude/init.sh
  ```
  Commit the resulting `.claude/settings.json` and `.claude/.template-version` diff. Push. Re-open the session on the web.
- **Local-only repos:** no action needed. Don't pass `--cloud-compat`.

### Why not just delete `failIfUnavailable` from base settings?

Considered. Rejected: users who explicitly run a local Linux sandbox WANT a hard failure when bubblewrap isn't installed — that's literally what the setting is for (managed deployments where sandboxing is a security gate). The flag lets the user pick per-repo whether they need the gate or whether they want cloud compatibility. Long-term, if cloud usage dominates, we'll revisit the default.

---

## [v0.1.13] — 2026-04-27

Fix: 7 rules adopted from pedrohcgs/claude-code-my-workflow had `paths:` frontmatter referencing files/dirs (`Slides/`, `Quarto/`, `master_supporting_docs/`, `Preambles/`, R-stack subdirs, three skills we don't ship) that don't exist in a generic user repo. Per [Claude Code's memory docs](https://code.claude.com/docs/en/memory), path-scoped rules only load when files matching the glob are accessed — so these rules were silently dead in every repo initialized from this template.

### What changed

- **Removed** `info/rules/content-invariants.md` (the "INV-1 through INV-12" set). Every invariant referenced a stack we don't assume (Beamer/Quarto/SCSS/R/ggplot2). Couldn't be generalized — dropping was cleaner than rewriting 12 invariants out of recognition.
- **Stripped `paths:` frontmatter** from 3 rules so they load unconditionally where they belong:
  - `research/rules/pdf-processing.md` (now active for any user with PDFs, not just `master_supporting_docs/**`)
  - `paper/rules/proofreading-protocol.md` (now active across LaTeX, Markdown, Word, Google Docs)
  - `paper/rules/post-flight-verification.md` (CoVe protocol; was scoped to skills we don't ship like `lit-review`/`research-ideation`/`interview-me`)
- **Generalized body** in 2 rules to drop R-stack specifics:
  - `info/rules/exploration-fast-track.md` (no more `R/scripts/output` subdir assumption — pick what your stack needs)
  - `info/rules/exploration-folder-protocol.md` (same)
- **Trimmed `paths:`** in 1 rule:
  - `info/rules/summary-parity.md` (dropped `**/*.qmd`, kept the 5 generic patterns)

### Post-init rule counts (one less per profile after dropping `content-invariants.md`)

| Profile | v0.1.12 | v0.1.13 |
|---|---:|---:|
| `info` | 10 | 9 |
| `research` | 13 | 12 |
| `paper` | 17 | 16 |
| `paper-latex` | 21 | 20 |
| `code` | 14 | 13 |

### Tests

4 new regression assertions in `tests/test-init.sh`:

1. No rule's `paths:` references unshipped directories (`Slides/`, `Quarto/`, etc.) or skills we don't ship (`lit-review`, `research-ideation`, `interview-me`).
2. Every `paths:` entry uses a generic user-repo pattern from a small allow-list (`.claude/**`, `explorations/**`, `CHANGELOG.md`, `README.md`).
3. `content-invariants.md` is gone from every profile.
4. The 3 unscoped rules carry no leading frontmatter.

97 tests total, all green.

### Honest note on what was wrong with v0.1.4 / D27

When we adopted 17 pieces from pedrohcgs we audited workflow shape (does this fit our generic template?) but didn't audit `paths:` frontmatter against the assumption that user repos don't have his specific layout. v0.1.13 closes that gap; the test allow-list prevents regression. **No content is lost in your repo from this fix** — these rules weren't loading; that was the bug.

### Not in scope (flagged for v0.1.14)

`paper/rules/cross-artifact-review.md` ships frontmatter using Cursor's `.mdc` format (`description:`, `globs:`, `alwaysApply:`). Claude Code ignores those fields entirely, so the rule loads unconditionally already. The misleading frontmatter is harmless but worth cleaning up.

---

## [v0.1.12] — 2026-04-21

**⚠ BREAKING for `paper` profile users.** Split the monolithic `paper` profile into two: a format-agnostic `paper` (prose/manuscript work for any format) and `paper-latex` (the LaTeX + BibTeX + TikZ layer on top).

### Why

The previous `paper` profile assumed LaTeX authoring. Users writing proposals, reports, or non-LaTeX manuscripts were getting TikZ prevention rules, `validate-bib` for BibTeX, and a `verify-reminder.py` hook triggering on `.tex` edits — none of which applied. Split is cleaner long-term and matches our `info` → `research` → `paper` → `paper-latex` inheritance pattern.

### New chain topology

```
info
  └── research
        └── paper               ← new: format-agnostic prose/manuscript
              └── paper-latex   ← new: LaTeX/BibTeX/TikZ layer
  └── code
```

### Moved from `paper` to `paper-latex`

- **Rules:** `latex-bibtex-discipline.md`, `tikz-prevention.md`, `tikz-library-bundle.md`, `tikz-snippets/` (5 `.tex` starters + README).
- **Skills:** `tikz` (MixtapeTools 6-pass collision audit), `validate-bib` (BibTeX structural + semantic validation).
- **Hooks:** `verify-reminder.py` (post-Edit reminder triggered on `.tex`/`.bib` edits).

### Stays in `paper`

Prose and peer-review tools — all format-agnostic:

- **Rules:** `humanize-prose`, `post-flight-verification`, `proofreading-protocol`, `cross-artifact-review`.
- **Skills:** `humanizer`, `analyze-paper`, `verify-claims`, `respond-to-referees`, `seven-pass-review`, `proofread`, `review-paper`, `audit-reproducibility`.
- **Agents:** all 5 (`claim-verifier`, `proofreader`, `editor`, `methods-referee`, `domain-referee`).
- **Hooks:** `notify.sh`, `log-reminder.py`.
- **Templates:** `journal-profile-template.md`.

### Post-init totals after the split

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `paper` (new scope) | 9 | 17 | 9 | 5 | 2 | 5 |
| `paper-latex` | 9 | 21 | 11 | 5 | 3 | 5 |

### Migration for existing `paper`-profile repos

If your manuscript is LaTeX, re-run the initialization with the `paper-latex` profile (or cherry-pick `latex-bibtex-discipline.md`, `tikz-*`, `tikz-snippets/`, `skills/tikz/`, `skills/validate-bib/`, `hooks/verify-reminder.py` from this release into your existing `.claude/`). If your paper work is format-agnostic, the new `paper` profile is lighter — nothing to do.

If you applied from v0.1.11 or earlier and want `/template-check` to recognize v0.1.12, bump your `.claude/.template-version` to `v0.1.12` after catching up.

### Other changes

- `init.sh`: `VALID_PROFILES` + `resolve_chain` + usage text + `TEMPLATE_VERSION` all extended for `paper-latex`.
- `tests/test-init.sh` (research repo): 91 tests, 13 new assertions ensuring `paper` does NOT ship `tikz`/`validate-bib`/LaTeX rules, and `paper-latex` inherits paper + adds the LaTeX layer.

---

## [v0.1.11] — 2026-04-20

`code` profile pre-empts per-host sandbox prompts for devops tooling.

- `profiles/code/settings.overlay.json`: `sandbox.excludedCommands` adds `helm:*`, `kubectl:*`, `kustomize:*`, `terraform:*`, `docker:*`, `podman:*`, `aws:*`, `gcloud:*`, `az:*`. Same trust model as base entries (`git:*`, `ssh:*`, `gpg:*`, `devbox:*`, `nix:*`).

**Why:** the Bash sandbox can intercept network for tools that honor proxy env vars, but Go-based binaries (`helm`, `kubectl`) use raw sockets and bypass the proxy. With base settings, every chart repo or kubeconfig context triggered a per-host "Network request outside of sandbox" prompt. Excluding these commands lets them run unsandboxed (matching the existing pattern for `git:*` etc.) — your `Edit/Write` denies on credential paths still apply.

**Other profiles unchanged.** `info`, `research`, `paper` profiles do not receive these excludes — verified by tests.

**Patch existing v0.1.x repos** without re-init: add the same nine entries to `.claude/settings.json` → `sandbox.excludedCommands`, or drop them into a gitignored `.claude/settings.local.json`.

---

## [v0.1.10] — 2026-04-20

Bug fix: auto-memory writes were being blocked by the sandbox.

- `settings.json`: `sandbox.filesystem.allowWrite` now includes `~/.claude/projects`. Without this, the first time Claude Code's auto-memory system tries to `mkdir ~/.claude/projects/<project-slug>/memory/` (e.g. via a subagent's Bash call), it hits `Operation not permitted` and silently loses the memory write. Symptom: agents acted as if memory was unavailable in repos initialized from v0.1.9 or earlier.
- `tests/test-init.sh`: regression assertion that `~/.claude/projects` stays in `allowWrite`.

This is a low-risk broadening — `~/.claude/projects/` is Claude Code's own session-state and memory tree, not a sensitive credential location. The deny list still blocks `~/.claude/settings.json` and `~/.claude.json` explicitly.

**Fix in existing repos initialized from v0.1.9 or earlier:** add `"~/.claude/projects"` to `.claude/settings.json` → `sandbox.filesystem.allowWrite`, or re-run `init.sh` from a v0.1.10+ clone.

---

## [v0.1.9] — 2026-04-20

Version tracking and `/template-check` slash command.

- `init.sh`: stamps `.claude/.template-version` on every run with `version=`, `profile=`, and `applied_at=`. Used by the new slash command below.
- `commands/template-check.md`: `/template-check` compares your stamp against the latest GitHub release. Prints the CHANGELOG delta if behind. Does not modify files.
- `README.md`: new `## Upgrading` section with the manual update flow. Automated `/template-upgrade` is deferred to v0.2 (needs a merge spec for user-owned files like `CLAUDE.md` and `project-conventions.md`).

---

## [v0.1.8] — 2026-04-20

Claude Code v2.1.113 improvements adopted.

- **Minimum Claude Code version bumped to v2.1.113** — closes a sandbox-bypass window on `Bash(dangerouslyDisableSandbox: true)` calls (v2.1.112 and earlier could bypass without a prompt under some conditions). Load-bearing for the template's permission posture, not cosmetic.
- `settings.json`: `sandbox.network.deniedDomains: []` as a discoverable empty extension point. Users' threat models differ (pentest/academic/enterprise); shipping the knob lets each tune without adding a new top-level field.
- `rules/autonomous-work.md`: new paragraph on Bash deny-rule coverage. As of v2.1.113, Bash permission patterns also match commands wrapped in common exec wrappers (`env`, `sudo`, `watch`, `ionice`, `nice`, `setsid`, `chrt`, `stdbuf`, `taskset`, `timeout`). So `env sudo rm -rf /` is caught by our existing denies automatically.
- Fixes also picked up for free: subagent `output_config.effort` 400 errors on models without effort support (affected our `xhigh` baseline), and resumed-compaction sessions that had been failing with "Extra usage is required for long context requests" after `PreCompact`.

---

## [v0.1.7] — 2026-04-17

`init.sh` metadata cleanup for "Use this template" consumer repos.

- `init.sh`: new `cleanup_template_metadata()` strips template-authored files that GitHub's "Use this template" leaves in consumer repos:
  - **`README.md`** — replaced with `# <repo-name>` stub if the current content looks like the template's own README (starts with `# agentic-repo-template`).
  - **`CHANGELOG.md`** — deleted if the top matches the template's release-history preamble ("User-facing history of this template").
  - **`CLAUDE.md`**, **`LICENSE`**, **`.gitignore`** — preserved (reasonable starting points).
- Negative case guarded: if the user has already replaced `README.md` / `CHANGELOG.md` with their own content, both are left untouched.
- Fixes a real leak observed in the wild (a consumer repo inherited 13KB of template README + 6.8KB of template CHANGELOG).

---

## [v0.1.6] — 2026-04-17

Release-management scaffolding.

- **CHANGELOG.md** — introduced. Anchor the release tags (v0.1.0–v0.1.5) that already exist; every future tag gets a matching entry here and a matching GitHub Release.
- **README.md** — new "Versioning and release model" section: `main` = latest stable, tags are addressable snapshots, GitHub Releases carry notes, `v0.1.x` is pre-stable (additive minor bumps).

---

## [v0.1.5] — 2026-04-17

Documentation polish. No new features.

- **README**: detailed profile contents matrix. Every plugin / rule / skill / agent / hook / template listed by exact name with per-profile ✓/— columns. New "what's common vs specific" summary up front.

---

## [v0.1.4] — 2026-04-16

Major `paper` profile expansion. 17 pieces adopted from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT) covering anti-hallucination, peer review, bibliography validation, revise-resubmit, proofreading, exploration sandbox.

**New skills** (paper profile):
- `verify-claims` — Chain-of-Verification via forked subagent
- `validate-bib` — structural + semantic bibliography validation
- `respond-to-referees` — R&R response letter generator
- `seven-pass-review` — 7 parallel forked review lenses
- `proofread` — three-phase propose → approve → apply
- `review-paper` — single-pass + adversarial modes
- `audit-reproducibility` — cross-check numeric claims against code

**New skill** (info profile — inherited by all profiles):
- `permission-check` — diagnose Claude Code's 6-tier permission stack

**New agents** (paper, dispatched via Task/Agent):
- `claim-verifier`, `proofreader`, `editor`, `methods-referee`, `domain-referee`

**New rules**:
- Paper: `post-flight-verification`, `proofreading-protocol`, `cross-artifact-review`
- Info: `summary-parity`, `exploration-fast-track`, `exploration-folder-protocol`, `meta-governance`, `session-logging`, `content-invariants`
- Research: `pdf-processing`

**New opt-in hooks** (paper, reference from `settings.local.json` to activate):
- `notify.sh`, `log-reminder.py`, `verify-reminder.py`

**New templates**:
- Info: `requirements-spec`, `constitutional-governance`, `exploration-readme`, `session-log`
- Paper: `journal-profile-template`

**init.sh extended**: `copy_profile_content` now handles `agents/`, `hooks/`, `templates/` subdirectories alongside the existing `rules/` and `skills/`. Backward-compatible.

**Post-init counts**:

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 10 | 1 | — | — | 4 |
| `research` | 9 | 13 | 1 | — | — | 4 |
| `paper` | 9 | 21 | 11 | 5 | 3 | 5 |
| `code` | 9 | 14 | 1 | — | — | 4 |

---

## [v0.1.3] — 2026-04-16

Vendored MixtapeTools `/tikz` collision-audit skill into the paper profile.

- `paper/skills/tikz/` — 6-pass visual-collision audit using mathematical gap calculations (label-on-arrow, boundary overlaps, crossing arrows, Bézier depth formulas). Adapted from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) with attribution. MixtapeTools-specific references (`/beautiful_deck`, `~/mixtapetools/...`) stripped.

---

## [v0.1.2] — 2026-04-16

TikZ tooling additions and `verbose` default.

- `settings.json`: `verbose: true` by default. Surfaces thinking summaries and detailed transcript output — valuable for async review of autonomous-work sessions.
- `paper/rules/tikz-prevention.md` — 6-rule protocol to prevent TikZ failure modes (P1 explicit node dimensions, P2 coordinate map, P3 no bare `scale=`, P4 directional edge labels, P5 start from snippets, P6 one tikzpicture per idea). Adapted from MixtapeTools via pedrohcgs.
- `paper/rules/tikz-library-bundle.md` — canonical TikZ preamble (`positioning, arrows.meta, calc, shapes.geometric, shapes.misc, decorations.pathreplacing, patterns, matrix, fit`) + specialty package guide (`tikz-cd`, `pgfplots`, `circuitikz`, `forest`).
- `paper/rules/tikz-snippets/` — 5 compilable standalone figures: `flowchart.tex`, `tree.tex`, `graph.tex`, `plot.tex`, `block-diagram.tex`.

---

## [v0.1.1] — 2026-04-16

Claude Opus 4.7 + Claude Code v2.1.111 support.

- `settings.json`: `effortLevel: "xhigh"`. Anthropic's explicit recommendation for coding/agentic work on Opus 4.7 per the [migration guide](https://platform.claude.com/docs/en/about-claude/models/migration-guide). Older models fall back to `high` gracefully.
- **README**: minimum Claude Code version bumped to **v2.1.111** (for Opus 4.7 support, auto-mode without flag, `/less-permission-prompts` + `/ultrareview` skills).
- `rules/autonomous-work.md`: added "Notes for Opus 4.7+" section documenting behavior changes (more literal instruction following; fewer subagents and tool calls by default — raise effort or ask explicitly; response length calibrated to complexity; real-time cybersecurity safeguards).

---

## [v0.1.0] — 2026-04-15

Initial release. Four profiles (`info` / `research` / `paper` / `code`) applied via self-cleaning `.claude/init.sh` script.

**Base `.claude/`:**
- `settings.json` — 8 baseline plugins (`superpowers`, `commit-commands`, `claude-md-management`, `session-report`, `hookify`, `claude-code-setup`, `feature-dev`, `elements-of-style`), comprehensive deny list with `Edit`/`Write` protection for sensitive paths (ssh, aws, gnupg, kube, gcloud, claude.json, gitconfig, npmrc, pypirc, docker config, netrc, shell init files), OS-level sandbox with `failIfUnavailable: true`, 4 hooks (SessionStart, ConfigChange, PreCompact, SessionEnd), `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `ENABLE_LSP_TOOL=1`, `alwaysThinkingEnabled: true`, `enableAllProjectMcpServers: false`.
- 3 base rules: `autonomous-work.md`, `pr-discipline.md`, `project-conventions.md`.
- `init.sh` — applies profile overlay (deep-merges settings via `jq`, copies rules/skills, appends CLAUDE.md guidance, merges skills.manifest), self-deletes.
- `refresh-skills.sh` — re-fetch upstream-sourced skills (currently `humanizer`).

**Profiles:**
- `info` — `writing-quality.md` rule.
- `research` — inherits info; adds `context7` plugin, `citation-discipline` + `reading-before-editing` rules; documents Scholar Gateway claude.ai connector as an external requirement.
- `paper` — inherits research; adds `latex-bibtex-discipline` + `humanize-prose` rules; vendored `humanizer` (git-upstream-sourced, refreshable) + `analyze-paper` (local) skills.
- `code` — inherits info (not research); adds `context7` plugin, `makefile-conventions` + `devbox-usage` + `testing-discipline` + `verification-before-done` rules; documents `/configure-ecc` + devbox as optional follow-ups.

**Root:**
- `README.md` with usage instructions and profile comparison.
- `CLAUDE.md` stub.
- `.gitignore` with strong secret-pattern block (`.env*`, `*.pem`, `*.key`).
- `LICENSE` — MIT.
