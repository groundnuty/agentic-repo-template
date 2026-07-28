# agentic-repo-template

A GitHub template repository with sane Claude Code defaults for autonomous work. Five profiles (`info` / `research` / `paper` / `paper-latex` / `code`) cover knowledge work, technical research, academic paper writing, LaTeX/TikZ manuscripts, and code-centric development.

## Quick start

### The CLI (recommended)

Installed as **`art`** — short, and free of the `/usr/sbin/arp` collision macOS would otherwise give you.

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/art.sh -o ~/.local/bin/art && chmod +x ~/.local/bin/art
```

Then, in any directory you want to work in — **local-only is fine; no GitHub repo, no fork, no remote**:

```bash
art init -p research     # or: info | paper | paper-latex | code   (arp profiles explains them)
```

That's the whole flow. Later: `art status` (what this repo runs), `art upgrade` (move it forward), `art fleet ~/repos` (see every template repo you have; `--apply` upgrades them), `art update` (pull a newer template into the cache).

### The whole fleet, from one machine

```bash
art hosts        # first run creates ~/.config/arp/hosts.conf — add a line per machine:
                 #   local     ~/repos
                 #   magent    ~/repos
art overview     # every host: repos, current vs behind, dirty trees, profile mix
```

Hosts are surveyed in parallel over ssh with a self-contained POSIX snippet — **nothing needs to be installed on the remote side**. An unreachable host contributes zero rows rather than failing the run. The list is curated on purpose: your ssh config is an infrastructure inventory, not a repo inventory.

`art` caches one shallow template clone in `~/.cache/arp`, so after the first fetch it works offline. It wraps the scripts below rather than replacing them.


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

The `paper` and `paper-latex` profiles additionally **install and verify** the `agentic-paper` capability plugin at project scope — the paper skills, agents and the texlab LSP config ship as a plugin now, not as file copies. That step needs the `claude` CLI on `$PATH` and (once) network access; see [Capability plugins](#capability-plugins-v030).

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

Bootstrap hands off to `init.sh`, so on the paper tiers it runs the capability-plugin step too (and honours `ARP_SKIP_PLUGIN_INSTALL=1` from the environment). A plugin failure exits 5 after the scaffold is complete, naming the commands to run by hand.

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

**Two delivery mechanisms, from v0.3.0.** Most rows are **file-copied** into `.claude/` by `init.sh`. Rows marked **⊕** arrive through the `agentic-paper` capability plugin instead: they never appear under `.claude/`, they live in the plugin cache, and they are addressed by their namespaced names (`/agentic-paper:review-paper`, `agentic-paper:claim-verifier`). See [Capability plugins](#capability-plugins-v030).

### Post-init totals

| Profile | Plugins | Rules | Always-on rule words | Skills | Agents | Hooks | Templates | `.mcp.json.example` |
|---|---:|---:|---:|---:|---:|---:|---:|:-:|
| `info` | 5 | 9 | ~1,070 | 2 | — | 1 | 6 | ✓ |
| `research` | 6 | 13 | ~1,870 | 2 | — | 1 | 6 | ✓ |
| `paper` | 7 | 17 | ~2,060 | 2 + **10 via plugin** | **5 via plugin** | 3 | 7 | ✓ |
| `paper-latex` | 7 | 18 | ~2,060 | 2 + **10 via plugin** | **5 via plugin** | 4 | 7 | ✓ |
| `code` | 6 | 12 | ~1,210 | 2 | — | 1 | 6 | ✓ |

"Always-on rule words" counts only rules **without** `paths:` frontmatter — the context every session actually carries. v0.2.0 cut this 61–75% per profile versus v0.1.22 (e.g. paper-latex 8,194 → 2,061 words); the rest loads only when matching files are touched, or lives in skills invoked on demand. On the paper tiers the plugin adds ~1,900 always-on tokens of its own (skill + agent descriptions) once installed.

Skills and Agents count what lands **under `.claude/`** plus, in bold, what the plugin delivers. The two file-copied skills on every profile are `checkpoint` and `permission-check`; the paper tiers file-copy **zero** agents. Hooks count shipped hook scripts under `.claude/hooks/`; all of them are **opt-in** (nothing runs until you reference it from `settings.local.json`).

### Plugins (7 unique — `context7` conditional, `agentic-paper` ours)

| Plugin | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `superpowers@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `commit-commands@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-report@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hookify@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `claude-code-setup@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `context7@claude-plugins-official` | — | ✓ | ✓ | ✓ | ✓ |
| `agentic-paper@agentic-plugins` ⊕ — the paper/LaTeX capability suite (v0.3.0+) | — | — | ✓ | ✓ | — |

The six `@claude-plugins-official` entries are enabled by declaration alone — Claude Code ships that marketplace. `agentic-paper@agentic-plugins` is **ours**, and a declaration alone installs nothing: `init.sh`/`upgrade.sh` run `claude plugin marketplace add` + `claude plugin install --scope project` and then verify. Every profile's base `settings.json` declares the `agentic-plugins` marketplace in `extraKnownMarketplaces`; only the paper tiers enable a plugin from it.

Dropped in v0.2.0: `elements-of-style` (dormant, natively superseded), `claude-md-management` (pre-Claude-5 model; `/doctor` trims natively), `feature-dev` (native `/code-review` supersedes) — re-enable any per-repo via `settings.local.json`.

### Rules (21 unique; ⊙ = path-scoped, loads only when matching files are touched)

| Rule | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `autonomous-work.md` — judgment-framed unattended discipline | ✓ | ✓ | ✓ | ✓ | ✓ |
| `operations.md` ⊙ — config mechanics (perms/MCP/deny coverage); fires on settings/MCP files | ✓ | ✓ | ✓ | ✓ | ✓ |
| `pr-discipline.md` — commit/PR format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `project-conventions.md` — per-project overrides (stub) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `writing-quality.md` — document-length calibration + worst AI-isms | ✓ | ✓ | ✓ | ✓ | ✓ |
| `prompt-shaping.md` — resolve fuzzy asks silently, surface only real decisions | ✓ | ✓ | ✓ | ✓ | ✓ |
| `summary-parity.md` ⊙ — regenerate drifting summaries, don't patch | ✓ | ✓ | ✓ | ✓ | ✓ |
| `exploration.md` ⊙ — explorations/ lifecycle + fast-track threshold | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-logging.md` — the committed record (auto-memory boundary stated) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `citation-discipline.md` — never cite from memory; /deep-research front door; WebSearch/WebFetch caveats | — | ✓ | ✓ | ✓ | — |
| `reading-before-editing.md` — full read before research edits | — | ✓ | ✓ | ✓ | — |
| `pdf-processing.md` ⊙ — native PDF reads; OCR gap → docling/ocrmypdf | — | ✓ | ✓ | ✓ | — |
| `knowledge-work-structure.md` — six dirs + capture-conclusions-as-they-happen + artifact rule | — | ✓ | ✓ | ✓ | — |
| `humanize-prose.md` — when to run `/agentic-paper:humanizer` | — | — | ✓ | ✓ | — |
| `post-flight-verification.md` — auto-trigger → `/agentic-paper:verify-claims` | — | — | ✓ | ✓ | — |
| `proofreading-protocol.md` — auto-trigger → `/agentic-paper:proofread` | — | — | ✓ | ✓ | — |
| `cross-artifact-review.md` — auto-trigger → `/agentic-paper:review-paper` | — | — | ✓ | ✓ | — |
| `latex-bibtex-discipline.md` ⊙ — LaTeX/BibTeX conventions | — | — | — | ✓ | — |
| `makefile-conventions.md` ⊙ | — | — | — | — | ✓ |
| `devbox-usage.md` ⊙ | — | — | — | — | ✓ |
| `testing-discipline.md` — tests define done; /verify + /run-skill-generator | — | — | — | — | ✓ |

Rules are the one surface a plugin **cannot** carry, so every row above is file-copied — including the four paper auto-trigger rules, which now point at the plugin's namespaced skills (`/agentic-paper:verify-claims`, `/agentic-paper:proofread`, `/agentic-paper:review-paper`, `/agentic-paper:humanizer`) instead of at bare names.

Moved in v0.3.0: `rules/tikz-snippets/` (5 compilable reference figures) → the plugin, as the `/agentic-paper:tikz` skill's `snippets/` (`${CLAUDE_PLUGIN_ROOT}/skills/tikz/snippets/`).

Deleted in v0.2.0: `meta-governance.md`, `verification-before-done.md`, `tikz-prevention.md` + `tikz-library-bundle.md` (→ the `tikz` skill's `PREVENTION.md`/`LIBRARIES.md`, now `/agentic-paper:tikz`), `exploration-fast-track.md` + `exploration-folder-protocol.md` (→ `exploration.md`).

### Skills (12 unique — 2 file-copied, 10 ⊕ plugin-delivered)

Invoke via `/<name>`. The ten **⊕** rows are **not** files under `.claude/skills/`: they arrive with the `agentic-paper` plugin and their real names are namespaced. Use the namespaced form — a bare `/tikz` will silently resolve to a leftover scaffold copy if one survives from an older version, which is exactly the failure the namespacing prevents.

| Skill | Source | info | research | paper | paper-latex | code |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `permission-check` | pedrohcgs | ✓ | ✓ | ✓ | ✓ | ✓ |
| `checkpoint` | pedrohcgs — structured session handoff (state, pointers, next actions) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `/agentic-paper:humanizer` ⊕ | [blader/humanizer](https://github.com/blader/humanizer) v2.9.1, byte-identical, MIT | — | — | ✓ | ✓ | — |
| `/agentic-paper:analyze-paper` ⊕ | local (generalized from a ccgrid2026 paper repo) | — | — | ✓ | ✓ | — |
| `/agentic-paper:verify-claims` ⊕ | [pedrohcgs](https://github.com/pedrohcgs/claude-code-my-workflow) — CoVe via forked subagent | — | — | ✓ | ✓ | — |
| `/agentic-paper:respond-to-referees` ⊕ | pedrohcgs — R&R response letter generator (ships its own output template) | — | — | ✓ | ✓ | — |
| `/agentic-paper:seven-pass-review` ⊕ | pedrohcgs — 7 parallel forked review lenses | — | — | ✓ | ✓ | — |
| `/agentic-paper:proofread` ⊕ | pedrohcgs — three-phase editorial pass | — | — | ✓ | ✓ | — |
| `/agentic-paper:review-paper` ⊕ | pedrohcgs — single-pass, `--adversarial`, `--peer <journal>` modes | — | — | ✓ | ✓ | — |
| `/agentic-paper:audit-reproducibility` ⊕ | pedrohcgs — cross-check numeric claims against code | — | — | ✓ | ✓ | — |
| `/agentic-paper:tikz` ⊕ | [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) — collision audit; carries `PREVENTION.md`, `LIBRARIES.md`, `snippets/`, and fires in prevention mode BEFORE new TikZ | — | — | ✓ | ✓ | — |
| `/agentic-paper:validate-bib` ⊕ | pedrohcgs — structural + semantic bib validation | — | — | ✓ | ✓ | — |

The LaTeX-specific skills (`tikz`, `validate-bib`) reach the `paper` tier too, because one plugin serves both tiers — they are inert without `.tex`/`.bib` files, and splitting them into a second plugin would break the cross-references the suite relies on.

### Agents (5 unique — ⊕ plugin-delivered, `paper` and `paper-latex` only)

Dispatched via `Task`/`Agent` subagents, not directly by the user. Format-agnostic (referee review lenses apply to any manuscript), so both paper tiers get them. From v0.3.0 **no agent is file-copied**: `.claude/agents/` does not exist on a fresh paper init. Dispatch by the namespaced `subagent_type`.

| Agent | Source | info | research | paper | paper-latex | code |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `agentic-paper:claim-verifier` ⊕ | pedrohcgs — fresh-context CoVe verifier (deliberately **no** `memory: project`) | — | — | ✓ | ✓ | — |
| `agentic-paper:proofreader` ⊕ | pedrohcgs — grammar/typo/overflow review | — | — | ✓ | ✓ | — |
| `agentic-paper:editor` ⊕ | pedrohcgs — desk review + picks 2 disagreeing referees | — | — | ✓ | ✓ | — |
| `agentic-paper:methods-referee` ⊕ | pedrohcgs — methods/rigor review | — | — | ✓ | ✓ | — |
| `agentic-paper:domain-referee` ⊕ | pedrohcgs — substantive review with disposition | — | — | ✓ | ✓ | — |

### Hooks (4 unique — file-copied, opt-in; reference from `settings.local.json` to enable)

Hooks deliberately stayed in the scaffold. A plugin hook is active whenever the plugin is enabled, which would silently convert these from opt-in to mandatory.

| Hook | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `git-guardrails.py` — deny destructive git (reset --hard, clean -f, force-push, blanket staging) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `notify.sh` — cross-platform desktop notification on session events | — | — | ✓ | ✓ | — |
| `log-reminder.py` — stop-hook reminder to update session log | — | — | ✓ | ✓ | — |
| `verify-reminder.py` — post-Edit reminder to compile/verify `.tex`/`.bib` files | — | — | — | ✓ | — |

### Templates (7 unique)

| Template | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `requirements-spec.md` — MUST/SHOULD/MAY + CLEAR/ASSUMED/BLOCKED format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `constitutional-governance.md` — non-negotiables vs preferences | ✓ | ✓ | ✓ | ✓ | ✓ |
| `exploration-readme.md` — `explorations/` sandbox README | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-log.md` — session-log format | ✓ | ✓ | ✓ | ✓ | ✓ |
| `archive-readme.md` — archived-exploration README | ✓ | ✓ | ✓ | ✓ | ✓ |
| `quality-report.md` — check results, findings, what wasn't checked | ✓ | ✓ | ✓ | ✓ | ✓ |
| `journal-profile-template.md` — per-venue review calibration | — | — | ✓ | ✓ | — |

`journal-profile-template.md` deliberately stays scaffold-side: you copy it and fill it in, and a version-pinned plugin cache is the wrong home for a file the user edits. Moved in v0.3.0: `response-to-referees.md` → the plugin, as the `/agentic-paper:respond-to-referees` skill's own output template.

### External requirements (documented, not shipped)

| Requirement | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| Scholar Gateway (claude.ai connector — enable once in account) | — | required | required | required | — |
| `jq` installed (init script dependency) | required | required | required | required | required |
| `claude` CLI on `$PATH` at init/upgrade time (capability-plugin install + verify) | — | — | required | required | — |
| `git` installed (`upgrade.sh` clones the template; `claude plugin marketplace add` clones the marketplace) | recommended | recommended | required | required | recommended |
| Network access at least **once** (first `claude plugin marketplace add`) | — | — | required | required | — |
| LaTeX distribution (`pdflatex`/`lualatex`/`xelatex` + `bibtex`) | — | — | — | required | — |
| `texlab` binary (the plugin configures the LSP; it cannot ship the server) | — | — | — | recommended | — |
| devbox installed (recommended) | — | — | — | — | recommended |
| `/configure-ecc` run (for language-specific skills) | — | — | — | — | recommended |

### Attribution

The scaffold itself vendors four pieces from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT): the `checkpoint` and `permission-check` skills, the `journal-profile-template.md` template, and the three paper hooks (`notify.sh`, `log-reminder.py`, `verify-reminder.py`). Each carries an inline attribution header.

From v0.3.0 the rest of the adopted corpus — the ten paper skills and five referee/editor agents — lives in the **`agentic-paper` plugin** and carries its attribution there: pedrohcgs (MIT), Hugo Sant'Anna's `clo-author` (used with permission), [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) for `tikz` (use freely, attribution appreciated, pinned to the pre-rewrite commit), and [blader/humanizer](https://github.com/blader/humanizer) v2.9.1 (MIT, redistributed byte-identical with `LICENSE` + `ATTRIBUTION.md` alongside it). See the [plugin's README](https://github.com/groundnuty/agentic-plugins/blob/main/agentic-paper/README.md).

## Requirements

- [Claude Code](https://claude.com/claude-code) **v2.1.187 or later** — the floor tracks the newest settings key the template ships (`sandbox.credentials`, added CC v2.1.187; silently inert below that). Earlier features assumed: `PreCompact`/`ConfigChange` hooks, exec-wrapper deny coverage (v2.1.113+), `Edit(path)` file-permission semantics (v2.1.210 recommended). npm `stable` dist-tag satisfies the floor.
- `jq` on your `$PATH` (for the init script's deep-merge).
- The **`claude` CLI on your `$PATH` at init/upgrade time** (v0.3.0+) — capability-plugin delivery is a real `claude plugin marketplace add` + `claude plugin install --scope project` + verify, run by `init.sh`/`upgrade.sh`. Only the `paper` tiers declare a plugin; on the other profiles the step is a no-op. Without the CLI, init exits 5 / upgrade exits 4 and prints the exact commands to run by hand.
- `git` on your `$PATH` — `upgrade.sh` clones the template, and `claude plugin marketplace add` clones the marketplace.
- **Scholar Gateway** claude.ai connector — enable in claude.ai account settings if using `research`, `paper`, or `paper-latex` profiles.
- A **LaTeX distribution** (`pdflatex`/`lualatex`/`xelatex` + `bibtex`) if using `paper-latex`, plus a `texlab` binary if you want the plugin's LSP to attach.

## What's in the template

### Base `.claude/` (shipped to every profile)

- `settings.json` — permissions (wildcard allow with bare tool names + deny list with `Edit(...)` rules for sensitive paths — `Edit(path)` covers all file-editing tools incl. `Write`/`NotebookEdit` per Claude Code v2.1.210+), sandbox (OS-level enforcement, cloud-safe by default — `enableWeakerNestedSandbox: true`, no `failIfUnavailable`; opt into the hard gate with `init.sh --strict-sandbox`; `sandbox.credentials.files` blocks sandboxed shells from reading credential dirs like `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config/gh`, `~/.netrc`), plugins (5 baseline, +`context7` on four profiles, +`agentic-paper` on the paper tiers), `extraKnownMarketplaces` (our `agentic-plugins` marketplace, on every profile), hooks (SessionStart / ConfigChange / PreCompact / SessionEnd), env (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`), `effortLevel: xhigh` + `verbose: true` tuned for agentic work.
- `CLAUDE.md` — project-conventions stub. Each profile appends a `CLAUDE.append.md` overview on init.
- `rules/` — four base rules: `autonomous-work.md`, `operations.md` (path-scoped), `pr-discipline.md`, `project-conventions.md`.
- `audit.log` — committed to git; `ConfigChange` hook appends a line on every `.claude/*` modification.
- `session-reports/` — session transcripts and git-state snapshots from `PreCompact` / `SessionEnd` hooks.
- `commands/template-check.md` — `/template-check` slash command; see [Upgrading](#upgrading).

### Post-init leftovers

- `refresh-skills.sh` — re-fetch upstream-sourced vendored skills listed in `.claude/skills.manifest.json`. **As of v0.3.0 no profile ships a manifest**: the only git-upstream skill the template ever vendored was `humanizer`, and it now lives in the `agentic-paper` plugin, where refreshing is `claude plugin update agentic-paper@agentic-plugins` and the upstream pin is the plugin's problem, not yours. The script still ships and is a clean no-op ("no manifest — nothing to refresh"); it stays for anyone who wants to vendor a git-sourced skill of their own by writing a manifest. Nothing in the template requires `git` for this any more.
- `.template-version` — stamp recording which template `version` / `profile` was applied and `applied_at` timestamp. Used by `/template-check`.
- `bootstrap.sh` (root-level) — one-command initializer for dropping the template into an existing directory; see [Bootstrap into an existing directory](#bootstrap-into-an-existing-directory). `init.sh` removes it from a repo it initializes (it's tooling for setting up *other* directories, not project content).

### Escape hatch

- `~/.claude/settings.local.json` or `.claude/settings.local.json` (gitignored) — merge with base at load time. Per-project `allow`/`ask`/`deny` overrides and hook activations live here.

## Capability plugins (v0.3.0+)

v0.3.0 splits the template into **two layers**, matching what the plugin substrate can and cannot carry:

- **Scaffold** — everything a plugin *cannot* ship: `settings.json`, rules, `CLAUDE.md`, `.gitignore`, hooks, templates, and the `.mcp.json.example` opt-in layer. File-copied by `init.sh` / `bootstrap.sh` / `upgrade.sh`, exactly as before.
- **Capability plugins** — versioned, natively updatable payload from a marketplace we own: [**groundnuty/agentic-plugins**](https://github.com/groundnuty/agentic-plugins).

There is exactly one today.

### `agentic-paper` — the paper + LaTeX suite

Declared by the `paper` and `paper-latex` profiles. It carries:

- **10 skills** — `/agentic-paper:review-paper`, `:seven-pass-review`, `:verify-claims`, `:respond-to-referees`, `:audit-reproducibility`, `:analyze-paper`, `:proofread`, `:humanizer`, `:tikz` (with `PREVENTION.md`, `LIBRARIES.md` and five `snippets/`), `:validate-bib`.
- **5 agents** — `agentic-paper:claim-verifier`, `:domain-referee`, `:methods-referee`, `:editor`, `:proofreader`.
- **1 LSP server** — `texlab`, mapping `.tex` → `latex` and `.bib` → `bibtex`. Install the binary yourself (`brew install texlab` or your platform's equivalent); a missing binary surfaces in `/plugin` → Errors only **after your first `.tex` edit**, not at session start.
- **Cost:** ~1,900 always-on tokens once installed (skill + agent descriptions). Nothing else is added to every session.

It deliberately does **not** ship hooks (they must stay opt-in), MCP servers (they stay in `.mcp.json.example` — see [The MCP layer](#the-mcp-layer-v020)), rules (plugins cannot ship them), or `journal-profile-template.md` (you edit that file; a version-pinned cache is the wrong home).

Update it with `claude plugin update agentic-paper@agentic-plugins`.

### Declaration is not installation

A committed `enabledPlugins` entry **installs nothing**. The marketplace registers, the plugin never arrives, and nothing errors — the skills are simply absent and Claude Code does not say so. That is why `init.sh` and `upgrade.sh` run a real three-step delivery, in your repo's directory:

```bash
claude plugin marketplace add groundnuty/agentic-plugins --scope project
claude plugin install agentic-paper@agentic-plugins --scope project
# then a PROJECT-SCOPED verify: the plugin must be enabled for THIS directory
```

`--scope project` on both commands, always. User scope would write to `~/.claude/settings.json`, which the template's own deny rules block. And the verify has to be project-scoped: `claude plugin list --json` is machine-global — it returns every plugin every repo on the box ever installed — so a naive "the id appears in the list" check goes green in repo #2 because repo #1 installed it.

If the step fails, it fails **loudly**: `init.sh` exits **5**, `upgrade.sh` exits **4**, and both print the exact commands to run by hand. In both cases the scaffold is complete and nothing was lost; only the plugin payload is missing.

### Offline and air-gapped

The honest story, as measured:

- Run **`claude plugin marketplace add groundnuty/agentic-plugins --scope project` once while online.** From then on `claude plugin install` works **offline**, from the local marketplace clone under `~/.claude/plugins/marketplaces/`. (`claude plugin uninstall` does not garbage-collect that clone — which is exactly what keeps later installs working offline.)
- For a fully offline init, set `ARP_SKIP_PLUGIN_INSTALL=1`. The scaffold applies normally and the script prints the two commands, prefixed by a warning that the declaration alone is a silent no-op. Run them yourself when you next have network.
- **`CLAUDE_CODE_PLUGIN_SEED_DIR` is not a substitute for the install.** It seeds marketplaces and caches into a *session*; `claude plugin install` does not consult it, and with a seed set but git transport dead the install fails with *"Plugin not found in marketplace"*. Treat it as container-image tooling for pre-baking the marketplace clone, not as the offline install path.

### Do not rename the marketplace key

The marketplace registers under the `name` field inside its `marketplace.json` — `agentic-plugins` — **not** under the repo slug. Every plugin id the template ships (`agentic-paper@agentic-plugins`), the `extraKnownMarketplaces` key in `settings.json`, and the install commands above all depend on that exact string. Renaming it, or pointing `extraKnownMarketplaces` at a fork under a different marketplace name, silently disarms the declaration: the profile asks for a plugin from a marketplace that is no longer registered under that key, and you get the silent-absence state above. Forking is fine — keep the `name` field.

## The MCP layer (v0.2.0+)

Each profile ships a **`.mcp.json.example`** at the repo root — pinned, opt-in MCP servers relevant to that profile (literature search, reference management, k8s, databases…). The file is valid JSON as shipped: every server is documented under an inert `"//<name>"` key; enable one by copying the file to `.mcp.json` and renaming its `"//<name>-uncomment"` key to `"<name>"`.

Three rules keep this safe:

1. **Do not rename the server keys.** The template pre-ships `permissions.allow` entries (and for `papers`, Sci-Hub **deny** rules) keyed to these exact names — renaming silently disarms them.
2. **MCP servers run outside the Bash sandbox.** `sandbox.network`, `denyRead`, and `credentials` do not constrain them. Enable only servers you trust; the `fetch` server in particular can reach internal IPs (upstream's own SSRF caution) and therefore ships commented-out.
3. **Live config stays local.** `.mcp.json` and `k8s-mcp.toml` are gitignored (they can carry DSNs and kubeconfig paths); use `${ENV_VAR}` references, never inline secrets. The `.example` files are template-owned and regenerated by `upgrade.sh`; your live `.mcp.json` is never touched.

Local servers need `uv` (for `uvx`) or Node (for `npx`) on PATH. Servers are version-pinned; bumping a pin is a deliberate act (watch the upstream repo for CVEs — the template refreshes pins per release, but your live `.mcp.json` is yours to update).

## Sandbox `excludedCommands` — why each entry (v0.2.0+)

Excluded commands run **entirely outside** the sandbox, and matching is broad (a pattern can match the whole invocation — [claude-code#45113](https://github.com/anthropics/claude-code/issues/45113), [#81157](https://github.com/anthropics/claude-code/issues/81157)). v0.2.0 removed `git:*` (it unsandboxed most autonomous commands, nullifying `denyRead`/`credentials` — the highest-severity finding of our July 2026 audit) and the substring-hazard entries (`nix:*` matched "unix"; `aws:*`/`az:*`/`gcloud:*` in the code profile matched ordinary words). What remains, and why:

| Entry | Why it cannot run sandboxed |
|---|---|
| `ssh:*`, `scp:*`, `rsync:*` | Remote transport; needs agent sockets + arbitrary hosts |
| `devbox:*` | Nix-backed store writes outside allowed paths |
| `git commit:*`, `git tag:*` | **Signed** commits/tags: git spawns gpg, which needs the `~/.gnupg` agent socket `sandbox.credentials` guards. Scoped to these two verbs — the blanket `git:*` hole stays closed (v0.3.1) |
| `gpg:*`, `gpg-agent:*` | Signing needs the `~/.gnupg` agent socket that `denyRead` guards |
| `helm/kubectl/kustomize/terraform/docker/podman:*` (code profile) | Go-binary TLS fails under Seatbelt; docker daemon socket |

Git now runs **sandboxed**. If signed tags or ssh-remote pushes fail in your environment, the failed command falls back to the regular permission flow (a prompt, not breakage); a per-repo escape hatch is `settings.local.json` → `sandbox.excludedCommands: ["git tag:*"]` — scope it to the narrow operation, never `git:*`.

## Auto mode and the classifier (user-machine config)

Claude Code's auto mode (default-on) is a classifier gate that runs *after* permission rules. Two things surprise people: it **suspends broad `Bash` allow rules** (bare `Bash` in allow does not mean "no prompts" — narrow rules like `Bash(npm test)` are honored, broad ones go to the classifier), and **subagents inherit it** (v2.1.212+), escalating classifier blocks to the leader. The fix is never to disable auto mode — it's to tell the classifier what to trust, in **`~/.claude/settings.json`** (the classifier deliberately ignores project settings so a checked-in repo can't self-trust):

```json
{
  "autoMode": {
    "environment": [
      "$defaults",
      "Key internal services: the host 'build-box' and its Kubernetes clusters are trusted internal dev infrastructure.",
      "Local scratch: $TMPDIR / /tmp and clones under it are trusted local working areas, not external destinations."
    ]
  }
}
```

Triage denials via `/permissions` → Recently denied (the reason names the fix); verify with `claude auto-mode config`. This is user-machine config — the template can't ship your trusted-infra list, which is why this section lives here and not in a rule.

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

Currently `v0.3.x` (pre-stable). Minor bumps are additive; breaking changes go in CHANGELOG as **BREAKING**.

Capability plugins version **independently** of the template: `agentic-paper` carries its own semver in its `plugin.json`, and its releases are tagged `agentic-paper--v<version>` in the marketplace repo. A template release does not force a plugin bump, or the reverse.

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

### Mass upgrades — `fleet-upgrade.sh` (v0.2.1+)

Many repos at once: discovers every stamped repo under the roots you give, reports, then `--apply` upgrades each with per-repo logs. Auto-skips repos with a live Claude session; never commits or pushes.

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/fleet-upgrade.sh -o /tmp/fleet.sh
bash /tmp/fleet.sh ~/repos && bash /tmp/fleet.sh --apply ~/repos
```

The report's `dirty` column is a **before** picture, computed once at discovery. `--apply` writes to every repo it touches — and from v0.3.0 the plugin step writes `settings.json` too — so an upgraded repo is normally dirty afterwards regardless of what the column said. A repo whose scaffold upgraded but whose plugin step failed shows as **FAILED** in its row (the upgrader's exit 4), with the full report in its per-repo log.

### Applying an update — `upgrade.sh` (v0.1.20+)

One command upgrades an already-initialized repo to the latest release. It reads `.claude/.template-version` for the profile and sandbox flags, so **you don't have to remember how the repo was initialized**:

```bash
# preview first (recommended) — shows the version jump, CHANGELOG delta, and any custom settings.json entries
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/arp-upgrade.sh
bash /tmp/arp-upgrade.sh --dry-run

# apply
bash /tmp/arp-upgrade.sh
```

Or, from inside a Claude Code session in the repo, run the **`/template-upgrade`** slash command — it runs the same flow and helps reconcile any custom `settings.json` entries.

What it does:

- **Backs up** the existing `.claude/` → `.claude.pre-upgrade-<oldversion>/` (gitignored).
- **Overlays** the template-owned files in place for your stamped profile + flags: `settings.json`, `skills/ agents/ hooks/ templates/ commands/`, profile rules, `refresh-skills.sh`. **Anything you added under `.claude/` is never touched** (v0.2.8+ — earlier upgraders destroyed custom files; recover from `.claude.pre-upgrade-*/`), and `.claude/CLAUDE.md` / `rules/project-conventions.md` are never overwritten (fresh template CLAUDE.md → backup as `CLAUDE.md.template-new`).
- **Preserves** your files: `settings.local.json`, `rules/project-conventions.md`, `.claude/CLAUDE.md`, `audit.log`, `session-reports/`.
- **Installs and verifies capability plugins** (v0.3.0+) — see below.
- **Bumps the stamp** to the new version and prints the CHANGELOG delta.

`settings.json` is **regenerated fresh, not merged** — a union merge would re-add entries the template deliberately removed (e.g. deprecated `Write(path)` denies). If you edited `settings.json` directly, the upgrader reports the custom entries so you can move them to `settings.local.json` (the intended home for overrides, preserved across upgrades). `--ref vX.Y.Z` targets a specific version.

#### The capability-plugin step (v0.3.0+)

On a profile that declares a plugin (today: `paper`, `paper-latex`), the upgrader adds a step **after** the overlay — it needs the regenerated `settings.json` on disk, and the CLI's own writes must not be clobbered by it:

1. `claude plugin marketplace add groundnuty/agentic-plugins --scope project`
2. `claude plugin install <plugin>@agentic-plugins --scope project` for each declared plugin
3. A **project-scoped verify** — the plugin must be enabled for *this* directory, not merely present in the machine-global plugin list. This verify, not the install's exit code, is the authority.
4. `jq -S` canonicalization of `settings.json`, because `claude plugin install` rewrites it in an unstable key order (three different orders and 162 churn lines were measured for one semantic addition).

**The step can never abort the scaffold upgrade.** It runs under a scoped `set +e`; whatever it does, the full upgrade report prints first. If it failed, the report is followed by `PLUGIN STEP FAILED` and the script **exits 4**: the scaffold upgrade is complete and safe, nothing was lost, but the plugin's skills and agents are absent — and Claude Code will not tell you so. The diagnostic names the exact commands; run them in the repo, then re-run the upgrader.

**Dedupe happens only when the verify is green.** Once the capability is provably present, the upgrader deletes the file copies the plugin now supersedes — the ten paper skills, the five agents, `rules/tikz-snippets/`, `templates/response-to-referees.md` — and prunes plugin-owned entries out of `skills.manifest.json`. Copies go to the backup, and every removal is listed. This is a correctness fix, not tidiness: on a bare-name collision a stale scaffold copy **silently wins** over the plugin, so a repo carrying both would keep running old content with no error and no version signal. A repo whose install failed keeps its file copies and keeps working; it just carries duplicates until the install succeeds.

**Re-running is safe and is the fix path.** "Already up to date" no longer short-circuits: the fast path still runs the marketplace-add, install, verify and dedupe before exiting, so a repo whose scaffold upgraded but whose plugin step failed cannot bury the failure behind a green "nothing to do". (On the fast path there is no backup for that run, so dedupe stashes the copies into `.claude.pre-upgrade-<version>-plugin-dedupe/` first — in case you hand-edited a shipped skill.)

**Offline / no CLI:** set `ARP_SKIP_PLUGIN_INSTALL=1` to skip the step entirely. The scaffold upgrade runs normally, the commands are printed instead of executed, and — because the verify never went green — **nothing is deduped**, so your existing file copies stay in place and the repo keeps working. Run the two commands later and re-run the upgrader to complete the migration.

**What the upgrade does not touch** (v0.2.8+, unchanged in v0.3.0): `.claude/CLAUDE.md`, `rules/project-conventions.md`, `settings.local.json`, `audit.log`, `session-reports/`, your live `.mcp.json`, and every custom file you added under `.claude/`.

<details><summary>Manual flow (if you prefer to cherry-pick by hand)</summary>

```bash
git clone https://github.com/groundnuty/agentic-repo-template.git /tmp/arp-latest
diff -r /tmp/arp-latest/.claude .claude | less   # cherry-pick settings/rules; skip CLAUDE.md + project-conventions.md
sed -i '' "s/^version=.*/version=vX.Y.Z/" .claude/.template-version   # re-stamp (macOS; drop '' on Linux)
```
</details>

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
