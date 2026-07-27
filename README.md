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

| Profile | Plugins | Rules | Always-on rule words | Skills | Agents | Hooks | Templates | `.mcp.json.example` |
|---|---:|---:|---:|---:|---:|---:|---:|:-:|
| `info` | 5 | 9 | ~1,070 | 2 | — | 2 | 6 | ✓ |
| `research` | 6 | 13 | ~1,870 | 2 | — | 2 | 6 | ✓ |
| `paper` | 6 | 17 | ~2,060 | 10 | 5 | 5 | 8 | ✓ |
| `paper-latex` | 6 | 19 | ~2,060 | 12 | 5 | 7 | 8 | ✓ |
| `code` | 6 | 12 | ~1,210 | 2 | — | 2 | 6 | ✓ |

"Always-on rule words" counts only rules **without** `paths:` frontmatter — the context every session actually carries. v0.2.0 cut this 61–75% per profile versus v0.1.22 (e.g. paper-latex 8,194 → 2,061 words); the rest loads only when matching files are touched, or lives in skills invoked on demand. Hook counts include opt-in hooks (enable via `settings.local.json`).

### Plugins (6 unique, `context7` conditional)

| Plugin | info | research | paper | paper-latex | code |
|---|:-:|:-:|:-:|:-:|:-:|
| `superpowers@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `commit-commands@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `session-report@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `hookify@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `claude-code-setup@claude-plugins-official` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `context7@claude-plugins-official` | — | ✓ | ✓ | ✓ | ✓ |

Dropped in v0.2.0: `elements-of-style` (dormant, natively superseded), `claude-md-management` (pre-Claude-5 model; `/doctor` trims natively), `feature-dev` (native `/code-review` supersedes) — re-enable any per-repo via `settings.local.json`.

### Rules (22 unique; ⊙ = path-scoped, loads only when matching files are touched)

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
| `humanize-prose.md` — when to run /humanizer | — | — | ✓ | ✓ | — |
| `post-flight-verification.md` — auto-trigger → verify-claims skill | — | — | ✓ | ✓ | — |
| `proofreading-protocol.md` — auto-trigger → proofread skill | — | — | ✓ | ✓ | — |
| `cross-artifact-review.md` — auto-trigger → review-paper skill | — | — | ✓ | ✓ | — |
| `latex-bibtex-discipline.md` ⊙ — LaTeX/BibTeX conventions | — | — | — | ✓ | — |
| `tikz-snippets/` — 5 compilable reference figures (guide-endorsed rich references) | — | — | — | ✓ | — |
| `makefile-conventions.md` ⊙ | — | — | — | — | ✓ |
| `devbox-usage.md` ⊙ | — | — | — | — | ✓ |
| `testing-discipline.md` — tests define done; /verify + /run-skill-generator | — | — | — | — | ✓ |

Deleted in v0.2.0: `meta-governance.md`, `verification-before-done.md`, `tikz-prevention.md` + `tikz-library-bundle.md` (→ `/tikz` skill's `PREVENTION.md`/`LIBRARIES.md`), `exploration-fast-track.md` + `exploration-folder-protocol.md` (→ `exploration.md`).

### Skills (12 unique; invoke via `/<name>`; `/tikz` now carries `PREVENTION.md` + `LIBRARIES.md` and fires in prevention mode BEFORE writing new TikZ)

| Skill | Source | info | research | paper | paper-latex | code |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `permission-check` | pedrohcgs | ✓ | ✓ | ✓ | ✓ | ✓ |
| `checkpoint` | pedrohcgs — structured session handoff (state, pointers, next actions) | ✓ | ✓ | ✓ | ✓ | ✓ |
| `humanizer` | [blader/humanizer](https://github.com/blader/humanizer) (git upstream, refreshable) | — | — | ✓ | ✓ | — |
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

### Hooks (4 unique — opt-in, reference from `settings.local.json` to enable)

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
| `response-to-referees.md` — R&R response letter scaffold | — | — | ✓ | ✓ | — |

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

The `paper` and `paper-latex` profiles adopt 17 pieces from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (MIT). `paper-latex` also vendors 1 piece from [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools) (use freely, attribution appreciated). Both profiles vendor [blader/humanizer](https://github.com/blader/humanizer) (git-upstream-sourced, refreshable via `refresh-skills.sh`). Each vendored file carries an inline attribution header.

## Requirements

- [Claude Code](https://claude.com/claude-code) **v2.1.187 or later** — the floor tracks the newest settings key the template ships (`sandbox.credentials`, added CC v2.1.187; silently inert below that). Earlier features assumed: `PreCompact`/`ConfigChange` hooks, exec-wrapper deny coverage (v2.1.113+), `Edit(path)` file-permission semantics (v2.1.210 recommended). npm `stable` dist-tag satisfies the floor.
- `jq` on your `$PATH` (for the init script's deep-merge).
- `git` on your `$PATH` (for the paper profiles' upstream-sourced skill refresh; optional otherwise).
- **Scholar Gateway** claude.ai connector — enable in claude.ai account settings if using `research`, `paper`, or `paper-latex` profiles.
- A **LaTeX distribution** (`pdflatex`/`lualatex`/`xelatex` + `bibtex`) if using `paper-latex`.

## What's in the template

### Base `.claude/` (shipped to every profile)

- `settings.json` — permissions (wildcard allow with bare tool names + deny list with `Edit(...)` rules for sensitive paths — `Edit(path)` covers all file-editing tools incl. `Write`/`NotebookEdit` per Claude Code v2.1.210+), sandbox (OS-level enforcement, cloud-safe by default — `enableWeakerNestedSandbox: true`, no `failIfUnavailable`; opt into the hard gate with `init.sh --strict-sandbox`; `sandbox.credentials.files` blocks sandboxed shells from reading credential dirs like `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config/gh`, `~/.netrc`), plugins (8 baseline), hooks (SessionStart / ConfigChange / PreCompact / SessionEnd), env (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, `ENABLE_LSP_TOOL=1`), `effortLevel: xhigh` + `verbose: true` tuned for agentic work.
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

### Mass upgrades — `fleet-upgrade.sh` (v0.2.1+)

Many repos at once: discovers every stamped repo under the roots you give, reports, then `--apply` upgrades each with per-repo logs. Auto-skips repos with a live Claude session; never commits or pushes.

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/fleet-upgrade.sh -o /tmp/fleet.sh
bash /tmp/fleet.sh ~/repos && bash /tmp/fleet.sh --apply ~/repos
```

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
- **Regenerates** the template-owned config for your stamped profile + flags: `settings.json`, `skills/ agents/ hooks/ templates/ commands/`, profile rules, `refresh-skills.sh`.
- **Preserves** your files: `settings.local.json`, `rules/project-conventions.md`, `.claude/CLAUDE.md`, `audit.log`, `session-reports/`.
- **Bumps the stamp** to the new version and prints the CHANGELOG delta.

`settings.json` is **regenerated fresh, not merged** — a union merge would re-add entries the template deliberately removed (e.g. deprecated `Write(path)` denies). If you edited `settings.json` directly, the upgrader reports the custom entries so you can move them to `settings.local.json` (the intended home for overrides, preserved across upgrades). `--ref vX.Y.Z` targets a specific version.

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
