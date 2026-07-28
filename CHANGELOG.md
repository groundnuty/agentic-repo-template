# Changelog

User-facing history of this template. Every version is a git tag with a matching GitHub Release; `main` is always the latest stable release.

Design rationale, empirical research, and decision history live in [agentic-repo-template-research](https://github.com/groundnuty/agentic-repo-template-research).

---

## [v0.3.4] — 2026-07-29

**The CLI installs as `art`.** The first real install exposed a name collision: macOS ships `/usr/sbin/arp` (the ARP protocol tool), which shadows `~/.local/bin/arp` on the default PATH, so `arp overview` ran the network utility and printed `Unknown host`. Same script, same subcommands, shorter name. If you installed v0.3.2/v0.3.3: re-install as `art` and delete the old `~/.local/bin/arp`.

---

## [v0.3.3] — 2026-07-29

**`arp overview` — every host at a glance.** One command on your main machine surveys all the machines you list and prints repo counts, how many are current vs behind, dirty working trees, and a profile breakdown per host, then names the repos that are behind:

```
arp hosts        # the surveyed list (created on first run; edit it — one line per host: <ssh-host|local> <roots…>)
arp overview     # the table
```

Hosts are surveyed in parallel over ssh with a self-contained POSIX snippet — **the remote side needs nothing installed**, not even `arp`. An unreachable host degrades to zero rows instead of failing the run. Deliberately a curated list, not an ssh-config scan: an infrastructure inventory is not a repo inventory.

---

## [v0.3.2] — 2026-07-29

**`arp` — a CLI, so initializing a repo is one command you can remember.**

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/art.sh -o ~/.local/bin/arp && chmod +x ~/.local/bin/arp

arp init -p research        # initialize THIS directory — any local dir, no GitHub, no fork, no remote
arp init -p paper ~/some/x  # ...or that one
arp upgrade                 # upgrade this repo
arp fleet ~/repos           # report every template repo under a root (--apply to upgrade them)
arp status                  # version, profile, and whether the declared plugin is actually installed here
arp profiles                # the five profiles, one line each
arp update                  # refresh the cached template to pick up new releases
```

It wraps the existing `bootstrap.sh` / `upgrade.sh` / `fleet-upgrade.sh` rather than duplicating them, and keeps one shallow template clone in `~/.cache/arp` (so after the first fetch it works offline, and `arp update` is the deliberate step that moves you to a new release). `ARP_SOURCE=/path/to/checkout` bypasses the cache for template development. Like `bootstrap.sh` and `fleet-upgrade.sh`, `art.sh` is operator tooling — `init.sh` removes it from consumer repos.

Nothing about this is new capability: `bootstrap.sh` already initialized any local directory. It was undiscoverable — you had to fetch it and remember the URL each time.

---

## [v0.3.1] — 2026-07-28

Two fixes found in production use of v0.3.0.

- **`.gitignore` now keeps transcript and cache artifacts out of git.** A blanket `git add .claude` (during a fleet upgrade) swept in session transcripts, **rescued transcript backups — one was 70 MB and broke that repo's push**, tool `.bak` files, `__pycache__`, and `.cc-writes/`. Ignored from now on: `.claude/session-rescue/`, `.claude/**/*.bak`, `.claude/.cc-writes/`, `.claude/**/__pycache__/` (session-reports were already covered). Existing repos: the rules arrive with this upgrade, but files already tracked stay tracked — `git rm -r --cached .claude/session-rescue .claude/session-reports` (etc.) once, then commit.
- **Signed commits and tags work under the sandbox again.** v0.2.8 closed the `git:*` sandbox hole; nobody re-tested `git commit -S` / `git tag -s`, and `gpg` invoked *by git* could no longer reach the `~/.gnupg` agent socket that `sandbox.credentials` guards — so signing failed and the fix was to bypass the sandbox entirely (more turns, less safety). Narrow `git commit:*` and `git tag:*` exclusions restore signing while the blanket `git:*` hole stays closed. Tests assert both.

---

## [v0.3.0] — 2026-07-28

**BREAKING — the two-layer split: scaffold + capability plugins.** Until now everything the template gave you was a file copy under `.claude/`. That is the wrong home for a versioned capability: skills and agents could not be updated without a full template upgrade, could not be versioned independently, and could not carry an LSP config at all. v0.3.0 splits the template in two:

- **Scaffold** — what a plugin genuinely cannot ship: `settings.json`, rules, `CLAUDE.md`, `.gitignore`, hooks, templates and the `.mcp.json.example` opt-in layer. Still file-copied by `init.sh` / `bootstrap.sh` / `upgrade.sh`, unchanged.
- **Capability plugins** — versioned, natively updatable payload from a marketplace we own: [`groundnuty/agentic-plugins`](https://github.com/groundnuty/agentic-plugins).

There is exactly one plugin today: **`agentic-paper` v1.0.0**, declared by the `paper` and `paper-latex` profiles. `info`, `research` and `code` are unaffected by this release beyond the docs.

Rationale, the empirical grounding and the rejected alternatives: research-repo decision log **D51** (architecture) and **D52** (marketplace + release ritual).

### What moved into `agentic-paper`

No longer file-copied into `.claude/` on a paper-tier init:

- **10 skills** — `review-paper`, `seven-pass-review`, `verify-claims`, `respond-to-referees`, `audit-reproducibility`, `analyze-paper`, `proofread`, `humanizer`, `tikz`, `validate-bib`.
- **5 agents** — `claim-verifier`, `domain-referee`, `methods-referee`, `editor`, `proofreader`. A fresh paper init now has **no `.claude/agents/` directory at all**.
- **`rules/tikz-snippets/`** → the `tikz` skill's `snippets/`.
- **`templates/response-to-referees.md`** → the `respond-to-referees` skill's own output template.
- **New: the `texlab` LSP config** — deferred from v0.2.0 because plugins are the only documented LSP delivery path. Maps `.tex` → `latex`, `.bib` → `bibtex`. You install the binary (`brew install texlab` or your platform's equivalent); a missing binary surfaces in `/plugin` → Errors only **after your first `.tex` edit**, not at session start.

**Every one of those names is now namespaced** — `/agentic-paper:review-paper`, `agentic-paper:claim-verifier`, and so on. This is a correctness requirement, not tidiness: on a bare-name collision a leftover scaffold copy **silently wins** over the plugin — no error, no version signal, stale content. Namespaced references make that failure loud.

Deliberately **kept in the scaffold**: all rules (plugins cannot ship them — the four paper auto-trigger rules now point at the namespaced skills); all hooks (`notify.sh`, `log-reminder.py`, `verify-reminder.py` are **opt-in by design**, and a plugin hook is active whenever the plugin is enabled, which would silently make them mandatory); MCP servers (they stay in `.mcp.json.example`, keeping the documented per-server approval path and leaving every existing `mcp__*` permission rule untouched); `templates/journal-profile-template.md` (you edit that file — a version-pinned plugin cache is the wrong home); and the `checkpoint` / `permission-check` skills.

### Delivery: install-and-verify, not declaration

**A committed `enabledPlugins` entry installs nothing.** The marketplace registers, the plugin never arrives, and *nothing errors* — the skills are simply absent and Claude Code does not say so. So `init.sh` and `upgrade.sh` now run a real delivery step, in your repo's directory:

1. `claude plugin marketplace add groundnuty/agentic-plugins --scope project`
2. `claude plugin install agentic-paper@agentic-plugins --scope project`
3. A **project-scoped verify** — the plugin must be enabled for *this* directory. `claude plugin list --json` is machine-global (it returns every plugin every repo on the box ever installed, plus user-scope ones), so a naive "the id appears in the list" check goes green in repo #2 because repo #1 installed it. The verify, not the install exit code, is the authority.
4. `jq -S` canonicalization of `settings.json` — `claude plugin install` rewrites it in an unstable key order (three different orders and 162 churn lines measured for one semantic addition).

`--scope project` on both commands, always: user scope writes `~/.claude/settings.json`, which this template's own deny rules block.

**Failure is loud, and never destructive.** `init.sh` exits **5**, `upgrade.sh` exits **4**. In both cases the scaffold is complete and correct and nothing was lost — only the plugin payload is missing — and the diagnostic names the exact commands to run by hand. `upgrade.sh`'s step runs under a scoped `set +e` and can never abort the scaffold upgrade; the full upgrade report always prints first. `fleet-upgrade.sh` shows such a repo as **FAILED** with the complete report in its per-repo log.

**"Already up to date" no longer short-circuits.** It used to `exit 0` immediately, which would have buried a failed plugin step forever: the stamp is a template-owned file the overlay copies, so it gets bumped even when the plugin step failed. The fast path now runs the add/install/verify (and the dedupe below) before exiting — re-running the upgrader is the documented fix path.

### Dedupe — and only when the verify is green

Once the capability is provably present for this repo, `upgrade.sh` deletes the file copies the plugin supersedes (manifest: `plugin-superseded-files.txt`) — the ten skills, five agents, `rules/tikz-snippets/`, `templates/response-to-referees.md` — and prunes plugin-owned entries out of `skills.manifest.json`. Copies land in the pre-upgrade backup and every removal is listed.

This is deliberately conditional. A repo whose install failed **keeps its file copies and keeps working**; it just carries duplicates until the install succeeds. And the semantics are distinct enough from the existing `removed-files.txt` (unconditional design removals) that they get their own manifest.

### Also changed

- **`extraKnownMarketplaces`** now declares `agentic-plugins` in every profile's base `settings.json`; only the paper tiers enable a plugin from it. Post-init `enabledPlugins` count: `info` 5, `research`/`code` 6, `paper`/`paper-latex` **7**.
- **`refresh-skills.sh` is now a no-op.** No profile ships a `skills.manifest.json` any more — the only git-upstream skill the template ever vendored was `humanizer`, and it now rides in the plugin, where refreshing is `claude plugin update agentic-paper@agentic-plugins`. The script still ships (it prints "no manifest — nothing to refresh") for anyone who wants to vendor a git-sourced skill of their own. **`git` is no longer required for it.**
- **`ARP_SKIP_PLUGIN_INSTALL=1`** — new environment escape hatch honoured by `init.sh`, `bootstrap.sh` (via `init.sh`) and `upgrade.sh`. Skips the CLI step, prints the two commands with a warning that the declaration alone is a silent no-op, and — because the verify never went green — **does not dedupe**, so file copies stay in place and the repo keeps working.
- **Post-init totals** (README matrix refreshed and re-verified against a real init of every profile): paper `2 skills + 10 via plugin`, `0 agents + 5 via plugin` (no `.claude/agents/` directory is created at all), 17 rules, 3 hook scripts, 7 templates; paper-latex the same but 18 rules and 4 hook scripts. The plugin adds ~1,900 always-on tokens once installed. The README's hook-script counts were overstated in earlier releases and are now the real shipped counts (1 / 1 / 3 / 4 / 1) — a docs correction, not a change to what ships.

### Requirements

Claude Code floor is unchanged at **v2.1.187**. New, for the paper tiers only:

- the **`claude` CLI on `$PATH`** at init/upgrade time;
- **network access at least once**, for the first `claude plugin marketplace add`;
- `git` (the marketplace add clones the marketplace).

### Offline and air-gapped

The honest story, as measured:

- Run **`claude plugin marketplace add groundnuty/agentic-plugins --scope project` once while online.** From then on `claude plugin install` works **offline**, from the local marketplace clone under `~/.claude/plugins/marketplaces/`. (`claude plugin uninstall` does not garbage-collect that clone — which is exactly what keeps later installs working offline.)
- **`CLAUDE_CODE_PLUGIN_SEED_DIR` is not a substitute for the install step.** It seeds marketplaces and caches into a *session*; `claude plugin install` does not consult it, and with a seed set but git transport dead the install fails with *"Plugin not found in marketplace"*. Treat it as container-image tooling for pre-baking the marketplace clone.

### Do not rename the marketplace key

The marketplace registers under the `name` field inside its `marketplace.json` — `agentic-plugins` — **not** under the repo slug. The plugin ids the template ships (`agentic-paper@agentic-plugins`), the `extraKnownMarketplaces` key, and the install commands all depend on that exact string. Renaming it, or pointing `extraKnownMarketplaces` at a fork registered under a different marketplace name, silently disarms the declaration and lands you in the silent-absence state above. Forking is fine — keep the `name` field.

### Migration

Nothing touches a consumer repo until you run `upgrade.sh`. Three shapes:

1. **Fresh init (`init.sh` / `bootstrap.sh`), online.** Nothing to do — pick `paper` or `paper-latex` and the plugin is installed and verified for you. On failure you get exit 5, a complete scaffold, and the two commands to run.
2. **Upgrade an existing paper repo, with network.** `curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/u.sh && bash /tmp/u.sh --dry-run`, then without `--dry-run`. The scaffold overlays first, then the plugin installs and verifies, then your now-superseded file copies are removed (backup keeps them) and listed. If it exits **4**, the scaffold is done and safe: run the named commands in the repo and re-run the upgrader — it re-verifies even when the scaffold is already up to date. Expect `settings.json` and `.claude/` churn in `git status`; review before committing.
3. **Upgrade offline / no `claude` CLI / air-gapped.** `ARP_SKIP_PLUGIN_INSTALL=1 bash /tmp/u.sh`. The scaffold upgrades, the plugin step is skipped with a warning, **nothing is deduped**, and your existing file copies keep the repo working exactly as it does today. When you next have network, run in the repo:
   ```bash
   claude plugin marketplace add groundnuty/agentic-plugins --scope project
   claude plugin install agentic-paper@agentic-plugins --scope project
   bash /tmp/u.sh          # re-run: it verifies, then dedupes
   ```
   Until you do, prefer the bare skill names your repo still has on disk; after you do, use the namespaced ones.

**What the upgrade does not touch** (the v0.2.8 overlay guarantees, unchanged): `.claude/CLAUDE.md`, `rules/project-conventions.md`, `settings.local.json`, `audit.log`, `session-reports/`, your live `.mcp.json`, and every custom file you added under `.claude/`.

### Known limitations

- The plugin's skills and agents live in the plugin cache, not in your repo, so they are **not** in your git history and not diffable per-commit. Pin with `claude plugin install agentic-paper@agentic-plugins` against a tagged marketplace ref if you need reproducibility.
- `claude plugin uninstall` does not garbage-collect the marketplace clone under `~/.claude/plugins/marketplaces/`.
- `fleet-upgrade.sh`'s `dirty` column is a **before** picture computed at discovery; the plugin step writes `settings.json`, so an upgraded repo is normally dirty afterwards regardless of what the column said.

---

---

## [v0.2.9] — 2026-07-28

**`effortLevel` back to `xhigh`** (was `high` since v0.2.0). v0.2.0 followed the Opus 5 docs' "start with high" guidance; the operator's standing directive is **Opus 5 + xhigh everywhere**, and since project settings override user-global settings, the template's `high` was silently downgrading effort inside every template repo against that intent. The planned Q3 effort sweep never ran, so the docs-default argument was never empirically backed for this workload; explicit operator preference wins (D50). Fleet picks it up at next upgrade; per-repo immediate override: `settings.local.json → {"effortLevel": "xhigh"}`.

---

## [v0.2.8] — 2026-07-28

**INCIDENT FIX — upgrades destroyed custom `.claude/` content (v0.2.0–v0.2.7).** The v0.2.0 upgrader replaced the whole `.claude/` tree, preserving only 4 hardcoded paths. Everything else a consumer kept in `.claude/` — custom rules, `scripts/`, `.macf/` frameworks, custom hooks, and hand-written `.claude/CLAUDE.md` project sections — was deleted on upgrade (recoverable from `.claude.pre-upgrade-*/`, but the live agent lost its project rules; this bit hard across a 49-repo fleet migration). The v0.2 pre-release review had recommended fence-or-diff for CLAUDE.md; the shipped implementation regenerated wholesale.

**New model: overlay, not swap.**

- Template-owned files (everything a fresh init generates) are **updated in place**.
- `.claude/CLAUDE.md` and `rules/project-conventions.md` are **never overwritten** — the fresh template CLAUDE.md (with profile appends) is saved to the backup as `CLAUDE.md.template-new` for deliberate manual merge.
- Files the template deliberately removed are deleted via a shipped manifest (`removed-files.txt`) — nothing else is ever deleted.
- **Every other file under `.claude/` is user content and is not touched.**

Regression test seeds the exact destroyed classes (custom rule, script, `.macf/env.*`, custom hook, edited CLAUDE.md, edited project-conventions, settings.local.json) into a customized repo and asserts all survive an upgrade in the live tree, while a design-removed file is deleted and template rules still update.

**If you upgraded any repo with v0.2.0–v0.2.7:** check `.claude.pre-upgrade-*/` for custom files and your old `CLAUDE.md`; restore anything missing (`diff -r` the backup against `.claude/`).

---

## [v0.2.7] — 2026-07-27

Fix: `upgrade.sh`'s settings-diff report was blind to **`extraKnownMarketplaces`** — a custom marketplace a consumer had added would vanish on regenerate-not-merge upgrade with **no report line at all** (silent loss of a user setting, the exact class v0.2's review named "worse than not fixing it"). The partition loop now covers it, and `removed-entries.json` carries the key so a future template-side marketplace change partitions DO-NOT-RESTORE vs your-customization correctly. Found while scoping v0.3 (its `marketplaces`→`extraKnownMarketplaces` migration would have inherited the gap); shipped standalone because the silent-loss risk is real for any current consumer using a custom marketplace.

---

## [v0.2.6] — 2026-07-27

**Settings audit — the base `settings.json` now says exactly what we mean.**

- **`enabledMcpjsonServers`** lists the ten curated `.mcp.json.example` server keys: enabling one of *our* servers is prompt-free, while any other server in a repo's `.mcp.json` still asks. A test now enforces settings ↔ example-key coherence (the do-not-rename contract, mechanized).
- **`mcp__claude_ai_alphaXiv__*` allow** — the doc-13 adoption that had silently never landed (its `/mcp` name probe was forgotten). Closes the preprint/conference search gap alongside DBLP.
- **`NotebookEdit` bare allow** — the one file-editing tool that still prompted (`Edit(path)` rules covered it for path checks; the tool-level allow was missing).
- **`Bash(git clean -df*)` / `-xf*` denies** — flag-order permutations that slipped past `git clean -f*` (the git-guardrails hook caught them; the always-on deny layer now does too).
- **`~/.cache/uv` + `~/.local/share/uv` in `sandbox.filesystem.allowWrite`** — our own docs say `uvx docling` / `uvx ocrmypdf`; without these the first sandboxed run failed on cache writes and fell back to a prompt.
- Schema check: every top-level key validates against schemastore except `marketplaces` — the known `marketplaces`-vs-`extraKnownMarketplaces` question (doc 13 §5); ours works in production across ~50 repos, and the v0.3 spike resolves the canonical form empirically.

---

## [v0.2.5] — 2026-07-27

Fix: the fleet report died (git rc=128 under `set -e`) on stamped repos with **no `.git`** — real fleets contain them (template-inited, never `git init`-ed). Field collection is now best-effort: such repos list as `dirty=-` and remain upgradable. Regression test adds a git-less repo to the test fleet.

---

## [v0.2.4] — 2026-07-27

Release-hygiene fix: tags v0.2.1–v0.2.3 shipped `init.sh` still claiming `TEMPLATE_VERSION="v0.2.0"` (the bump edits silently never landed), so fleet-upgraded repos were stamped `v0.2.0` — content-correct (those releases only changed operator scripts), version-string wrong. Now bumped for real, and a new test asserts `TEMPLATE_VERSION` equals the newest CHANGELOG entry so a missed bump fails the suite instead of shipping.

---

## [v0.2.3] — 2026-07-27

Fix: `upgrade.sh` died silently (zero output, nonzero exit) on repos stamped **before v0.1.14** — their stamps lack the `cloud_compat=`/`strict_sandbox=` keys, and under `set -o pipefail` the failed `grep` in `stamp_get` killed the script before its first line. Found by the first fleet run (8 of 17 repos failed, in perfect correlation with stamp age); our functional tests only ever used freshly-stamped repos. `stamp_get` now tolerates missing keys; regression test upgrades a two-key v0.1.13-style stamp.

---

## [v0.2.2] — 2026-07-27

Fix: `fleet-upgrade.sh` found nothing when the root was a **symlink** (`~/repos -> Dropbox/...` — the exact first production run). Roots are now resolved physically before discovery. Regression test runs the fleet through a symlinked root.

---

## [v0.2.1] — 2026-07-27

**`fleet-upgrade.sh` — mass upgrades across many repos.** One command discovers every template-initialized repo under the given roots (by its `.claude/.template-version` stamp), reports version/profile/dirty-count, and — with `--apply` — runs `upgrade.sh` in each, capturing per-repo logs (including the partitioned settings reports) and a final upgraded/current/skipped/failed summary. Safety: report-only by default; repos with a **live Claude Code session** (a `claude` process cwd'd inside) are auto-skipped unless `--force-live`; `--skip <name>` excludes repos; it never commits and never pushes. Operator tooling: `init.sh` removes it from consumer repos like `bootstrap.sh`/`upgrade.sh`.

```bash
curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/fleet-upgrade.sh -o /tmp/fleet.sh
bash /tmp/fleet.sh ~/repos              # report
bash /tmp/fleet.sh --apply ~/repos      # upgrade everything found
```

---

## [v0.2.0] — 2026-07-27

**BREAKING — the context-engineering rethink for Claude 5 generation models.** The Claude 5 guides (July 2026) deprecated the pattern this template was built on: large always-loaded rule sets constrain judgment that current models exercise correctly, and several shipped instructions had become sign-inverted (delegation, verification). v0.2.0 rebuilds around a thin always-on core + conditional (path-scoped) rules + skills + an opt-in MCP layer. Full rationale: decision log D44–D47; adversarial pre-release review: `docs/plans/2026-07-27-v0.2-plan-review.md` in the research repo.

### Security: the `git:*` sandbox hole is closed

`sandbox.excludedCommands: ["git:*"]` unsandboxed the **entire Bash invocation** whenever git appeared in it — most autonomous commands — silently disabling `denyRead` and `credentials` protections (verified July 2026; cf. claude-code#45113, #81157). Removed, along with the substring-hazard entries (`nix:*`; code profile's `aws:*`/`az:*`/`gcloud:*`). Every surviving exclusion now has a documented justification (README table). Git runs sandboxed; if signed tags or ssh pushes fail in your setup, the command falls back to a permission prompt — narrow escape hatch documented, never `git:*`.

### Removed (do NOT restore these from your upgrade backup)

- **Rules deleted:** `meta-governance.md` (described the upstream author's repo; its two-tier memory scheme fought native auto-memory), `verification-before-done.md` (mandated the extra verification pass Opus 5 performs natively; replaced by `/verify` + `/run-skill-generator` pointers), `tikz-prevention.md` + `tikz-library-bundle.md` (moved INTO the `/tikz` skill as `PREVENTION.md`/`LIBRARIES.md` — prevention must fire when *writing* TikZ, and path-scoped rules only fire on read), `exploration-fast-track.md` + `exploration-folder-protocol.md` (merged into one `exploration.md`).
- **Plugins dropped:** `elements-of-style` (dormant 9 months, unpinnable, natively superseded by Claude 5 prose + `/humanizer`), `claude-md-management` (frozen since Jan 2026, encodes the pre-Claude-5 "comprehensive CLAUDE.md" model that `/doctor` now trims natively), `feature-dev` (native `/code-review <effort>` supersedes its reviewer; re-add per-repo via `settings.local.json` if you relied on it). The orphaned `superpowers-marketplace` entry is gone with elements-of-style.
- **Settings keys dropped:** `alwaysThinkingEnabled` (thinking is on by default on Claude 5), `env.ENABLE_LSP_TOOL` (undocumented no-op — LSP gates on plugin presence).
- **All `superpowers:verification-before-completion` mandates** (three places) — compounded with native self-verification into pure token waste.

### Changed

- **`effortLevel: "xhigh"` → `"high"`** — the Opus 5 documented default; xhigh was an Opus 4.7 carry-over the docs explicitly say to re-sweep. Step up per-session with `/effort` for the hardest work.
- **`autonomous-work.md` rewritten** (1,257 → ~600 words): delegation guidance inverted for Opus 5 (constrain, don't encourage; keep fresh-context verifiers, drop same-context re-checks), stuck-threshold raised (routine judgment calls happen; stop only on material divergence/risk), task-scoping line added, model-era notes deleted under a standing policy (they decay faster than releases — the official prompting docs are the reference now).
- **Config-mechanics notes moved** to a new path-scoped `rules/operations.md` (loads when touching settings/MCP files); the auto-mode playbook moved to the README (user-machine config, not repo config).
- **Rules corpus dieted and path-scoped** — `pdf-processing`, `latex-bibtex-discipline`, `makefile-conventions`, `devbox-usage` now load only when matching files are touched; `writing-quality`, `prompt-shaping`, `knowledge-work-structure`, `reading-before-editing`, `testing-discipline`, `summary-parity`, `humanize-prose` shrunk to their kernels. Paper protocol rules (`cross-artifact-review`, `post-flight-verification`, `proofreading-protocol`) became ~45-word auto-triggers pointing at their skills (single source of truth; automatic invocation preserved).
- **`.claude/CLAUDE.md` is now REGENERATED on upgrade** (previously preserved wholesale — which meant profile-append fixes never reached upgraded repos). Your previous copy lands in the upgrade backup; durable per-project notes belong in `rules/project-conventions.md`, which is still preserved.
- **`citation-discipline`** gains the `/deep-research` front door + two operational facts: WebSearch caps at 200 calls/session **across all subagents, failing silently**; WebFetch is lossy — use the `fetch` MCP server or curl for verbatim quotes.
- **humanizer re-vendored from `blader/humanizer` v2.9.1** (pinned tag; the groundnuty fork is retired). Not cosmetic: v2.9.0 added the no-fabrication rule and repaired examples that modelled inventing facts.
- **`/validate-bib`** gains an existence + retraction pass (Crossref/OpenAlex DOI resolution; a DOI resolving to a *different* paper is the fabrication signature — always CRITICAL). **`/respond-to-referees`** gains latexdiff wiring (`tlmgr install latexdiff` on BasicTeX). Referee/editor/proofreader agents gain `memory: project`; `claim-verifier` deliberately does not (fresh context is its point).

### New

- **The MCP layer:** per-profile `.mcp.json.example` at the repo root — pinned, opt-in, valid-JSON-as-shipped (enable by renaming a key, no comment-stripping). research: DBLP (CS proceedings — closes the Scholar Gateway gap), arXiv (local corpus under `papers/`), OpenAlex. paper: + `paper-search-mcp` (21-source search; its two Sci-Hub tools are **hard-denied** in settings — keep the server key named `papers`) + Zotero (local read-only; or the zero-MCP Better BibTeX auto-export route). paper-latex: + arXiv-LaTeX. code: + Kubernetes (Red Hat server, read-only flag + Secret denylist via `k8s-mcp.toml.example`), dbhub, Prometheus. All commented-out by default, including `fetch` (upstream SSRF caution). `.mcp.json`/`k8s-mcp.toml` are gitignored.
- **`upgrade.sh` hardened** (this is what makes v0.2 deliverable): atomic assemble-then-swap (no half-upgraded state on crash), root-level template files regenerate (`.example` files reach existing repos; your live `.mcp.json` is never touched), the settings report now covers `enabledPlugins`/`marketplaces`/`env`/top-level keys (previously silently dropped), and it **partitions** removals-by-template (labeled *do NOT restore*) from your customizations — the previous report taught users to restore removed entries.
- **Multi-machine note** in `autonomous-work.md` (auto-memory is machine-local; shared state goes through git) — replacing the deleted meta-governance guidance.

### Migration paths

1. **Standard repos:** `curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/u.sh && bash /tmp/u.sh` (dry-run first if cautious). Read the partitioned settings report: restore **nothing** from the "REMOVED BY THE NEW TEMPLATE" list; move your customizations to `settings.local.json`. Merge any personal edits to `.claude/CLAUDE.md` from the backup. First session after: expect the classifier/sandbox to prompt on signed-tag/ssh-push git operations if your environment needs the escape hatch above.
2. **Repos that relied on dropped plugins** (`feature-dev` reviewers, `elements-of-style`): re-enable per-repo in `settings.local.json` (`"enabledPlugins": {"feature-dev@claude-plugins-official": true}`) — the upgrade report lists exactly what was dropped.
3. **Repos with heavy hand-edits to deleted rules:** everything is in `.claude.pre-upgrade-*/`; the CHANGELOG section above lists every deleted/moved file and its successor.

### Known limitations

- texlab LSP integration is **deferred to v0.3** — plugins are the only documented LSP delivery path, and profile plugin-ization is v0.3's scope.
- The superpowers plugin stays (its SessionStart injection and all): upstream is **open to a slim variant gated on their eval suite** — the right fix is upstream or a measured vendor-the-used decision, both pending usage data. See D45.
- `--cloud-compat` flag retained (removal re-deferred; D36's promise is tracked).

---

## [v0.1.22] — 2026-07-25

**Upstream audit release.** First systematic re-audit of the content vendored from [pedrohcgs/claude-code-my-workflow](https://github.com/pedrohcgs/claude-code-my-workflow) (April 2026) and [scunning1975/MixtapeTools](https://github.com/scunning1975/MixtapeTools). Fixes three real bugs in shipped content, resolves six dead cross-references, adds two upstream logic improvements, and ships three new generic pieces. No breaking changes.

### Bugs fixed in content we were already shipping

1. **`pdf-processing.md` told Claude the wrong thing.** It instructed *"Claude DOES NOT attempt to read it directly"* and mandated Ghostscript pre-splitting — false since the Read tool gained native PDF support with a `pages` parameter. Every research/paper session was being told to shell out before reading any paper. Now defaults to a direct read, with splitting demoted to a fallback for oversized or corrupt files. (Upstream fixed this on 2026-05-31; we were shipping the pre-fix version.)
2. **`log-reminder.py` was half-dead.** Introduced by our own generalization pass, not upstream: the lookup used `quality_reports/session_logs` while the user-facing message said `.claude/session-reports/`. That directory never exists here, so the staleness check could **never** fire. One-line fix.
3. **`/tikz` had an unreachable exit condition.** Step 3 gated on `pdflatex … | grep -E "Overfull|Underfull|Error|Warning"` returning **zero lines** — unachievable on any real manuscript, where bibliography and font warnings are always present, so the skill would thrash. The gate is now "no *new* warnings vs. a baseline," with the 3-strikes circuit breaker from `tikz-prevention.md`. Step 4's unbounded whole-file re-audit (quadratic in figure count) is now a single bounded re-audit of touched figures.

### Six dead cross-references resolved

Vendored content referenced files that only exist in the upstream repo. The worst: **`editor.md` instructed a hard `STOP`** if `.claude/references/journal-profiles.md` was missing — a file this template has never shipped — so `/review-paper --peer` halted on first use in a fresh repo, by design. The peer pipeline now calibrates from general venue norms when no profile exists and says so.

- `references/journal-profiles.md` → graceful degradation (also corrected a claim that we ship 5 econ journal profiles; we ship none)
- `rules/replication-protocol.md` → tolerances were already inlined in the skill; references now point there
- `rules/content-invariants.md` → removed (that file was deleted in v0.1.13/D34)
- `templates/response-to-referees.md`, `templates/archive-readme.md`, `templates/quality-report.md` → **now shipped** as real templates

### Upstream logic improvements adopted

- **`claim-verifier` severity tiers.** A `cannot-verify` is no longer treated uniformly: contradicted-by-source → HIGH-WARN, transient retrieval failure → MED-WARN, genuinely inaccessible → LOW-WARN, and a new **EXPLAINED** disposition for a contradiction the author has documented with a concrete alternative. The hard floor: **a cited work that does not exist is always HIGH-WARN and is never downgradable** — the canonical hallucination signature. `/verify-claims` aggregates tier-aware, and now documents how it differs from `/validate-bib` (existence vs. appropriateness).
- **Synthesis discipline in `/seven-pass-review` and `/review-paper`.** "Reduce, don't re-review": the executive verdict is a function of the typed lens findings, not a fresh eighth opinion. Plus a **post-judge hallucination gate** — any CRITICAL the synthesis introduces that *no lens raised* must be re-verified in a fresh `claim-verifier` fork or dropped as `[JUDGE-HALLUCINATED]` with the verdict recomputed. `/review-paper --adversarial` now runs **loop-until-dry** (converges when a round adds 0 new CRITICAL/MAJOR, deduped on location+finding) instead of a fixed 5-round cap.

### New

- **`git-guardrails.py`** (opt-in hook, all profiles) + five new deny rules. `git reset --hard` and `git clean -fdx` were **completely unguarded** before this release. The hook additionally catches forms that literal deny patterns cannot: `git -C /repo reset --hard`, `git -c k=v clean -fd`. Allows `--force-with-lease`, `clean -n`, `reset --soft`.
- **`prompt-shaping.md`** (rule, all profiles) — shape a fuzzy request into Role/Task/Context/Constraints/Output before acting, silently; surface only the genuine decision.
- **`checkpoint`** (skill, all profiles) — structured session handoff (state, file pointers with line numbers, next 1–3 actions) written to `.claude/session-reports/`. The structured counterpart to the narrative session log.

### Domain-specific paths generalized

Swept upstream's R/Stata/Quarto/Beamer specifics out of the vendored files: `master_supporting_docs/`, `scripts/R/_outputs/`, `renv.lock`/`sessionInfo.txt` as *the* environment capture, `Slides/*.tex`, `Quarto/*.qmd`, and the DiD worked examples in `claim-verifier`/`verify-claims`. The paper profiles are now genuinely language-agnostic; `papers/` and `input/` (per `knowledge-work-structure.md`) replace the upstream document paths.

### Not adopted, deliberately

- **MixtapeTools' `/tikz` rewrite.** Upstream replaced the six-pass repair tool with a three-check reporter (260 → 166 lines). It drops the audit-side enforcement of prevention rules P1–P4 — upstream could afford that because they moved enforcement into `beautiful_deck`, which we don't ship — and it inverts the skill's founding premise from "Claude cannot reliably eyeball TikZ collisions" to "read the image, Claude is multimodal." We took the good parts (visual mode as an explicit *fallback* for rasters with no source, the toolchain fix tables, the bounded loop) and kept measurement as the default.
- **`audit-reproducibility`'s upstream diff** (113 lines) — the most domain-drenched change in the set (`haven::read_dta`, `reghdfe` vs `feols`, `_targets/`, a passport-YAML mode) with six new cross-refs to files we don't ship.
- **Model-pin frontmatter** on agents (`model: opus`, `effort: high`) — that's upstream's routing policy; ours stay `inherit` so the user's model choice wins.
- **`model-routing.md`** (pins model names that go stale) and **`/diagnose`** (domain-tuned; overlaps `superpowers:systematic-debugging`).

### Post-init counts

| Profile | Plugins | Rules | Skills | Agents | Hooks | Templates |
|---|---:|---:|---:|---:|---:|---:|
| `info` | 8 | 10 | 2 | — | 1 | 6 |
| `research` | 9 | 14 | 2 | — | 1 | 6 |
| `paper` | 9 | 18 | 10 | 5 | 4 | 8 |
| `paper-latex` | 9 | 22 | 12 | 5 | 6 | 8 |
| `code` | 9 | 14 | 2 | — | 1 | 6 |

### Tests

15 new assertions, including a **generalized dead-reference scanner** — the v0.1.21 `/review-r` check widened to catch this whole class of bug (vendored content pointing at upstream-only files) automatically. 213 tests total, all green.

### Upgrading

`curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/u.sh && bash /tmp/u.sh` — reads your stamp, no profile argument needed.

---

## [v0.1.21] — 2026-07-21

Security hardening + docs + a dead-reference fix. No breaking changes.

### `sandbox.credentials.files` — block sandboxed reads of credential dirs

Added `sandbox.credentials.files` to base `settings.json` (Claude Code v2.1.187+). Sandboxed Bash commands can, by default, *read* credential files even though they can't write them — a `cat ~/.ssh/id_rsa` inside the sandbox succeeds. This block denies sandboxed reads of `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/.config/gcloud`, `~/.config/gh`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`, and `~/.docker/config.json` — extending coverage well beyond the four paths already in `sandbox.filesystem.denyRead` (kept as a pre-v2.1.187 compatibility floor). Pure hardening; nothing legitimate reads these during a build/test.

**`sandbox.credentials.envVars` is intentionally NOT shipped in base**, and here's why: `deny` (unset the var for sandboxed commands) would break tools that need the token — `gh`, `npm` — inside the sandbox, and `mask` (the keep-tools-working option) requires `network.tlsTerminate` and is **ignored when it lives in project `settings.json`** (only user/managed settings honor it), which is exactly where the template ships. Cloud + Anthropic credentials are already stripped from every subprocess by `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`. If you want env-var scrubbing for other tokens, add `sandbox.credentials.envVars` to your own `~/.claude/settings.json` (`deny`, or `mask` with `tlsTerminate`).

### Auto-mode playbook → `rules/autonomous-work.md`

New section documenting the interaction that causes the most confusing prompts: **auto mode suspends broad `Bash` allow rules** (so bare `Bash` in `permissions.allow` doesn't stop prompts — the classifier decides), **subagents inherit the session's auto mode** (v2.1.212+) and escalate classifier denials to the leader, and the fix is `autoMode.environment` / `autoMode.allow` in **`~/.claude/settings.json`** (the classifier ignores project settings). Includes the `/permissions` → Recently denied triage flow.

### Fixed `/review-r` dead reference (paper profile)

`cross-artifact-review.md` and the `review-paper` / `audit-reproducibility` skills referenced `/review-r`, an R-specific code-review skill from the upstream pedrohcgs workflow that this template **does not ship**. Generalized to a language-agnostic "review the referenced scripts" instruction (D34-class cleanup). Also removed the dead Cursor `.mdc` frontmatter (`globs:` / `alwaysApply:`, which Claude Code ignores) and stale cross-refs from `cross-artifact-review.md` while there.

### Changelog scan (v2.1.215 → v2.1.216)

Reviewed; nothing forces a template change. v2.1.215's breaking "`/verify` and `/code-review` no longer auto-run" doesn't touch us (we auto-invoke only our own skills). v2.1.214's hook `if:` glob change and `dir/**` allow-rule change don't apply (we use neither). New `sandbox.filesystem.disabled` not adopted (we want isolation).

### Tests

7 new assertions: `sandbox.credentials.files` present with deny entries for the key credential dirs; no `/review-r` reference anywhere in the paper profile. 198 tests total, all green.

---

## [v0.1.20] — 2026-07-18

New: `upgrade.sh` + `/template-upgrade` — one-command upgrade of an already-initialized repo. This is the automated upgrade path deferred since v0.1.9 (D30).

### What changed

- **`upgrade.sh`** (new, repo root). Upgrades the current repo to the latest release with no arguments — it reads `.claude/.template-version` for the profile and sandbox flags (`cloud_compat`, `strict_sandbox`), so you don't have to remember how the repo was initialized.

  ```bash
  curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/arp-upgrade.sh
  bash /tmp/arp-upgrade.sh --dry-run   # preview: version jump, CHANGELOG delta, custom settings.json entries
  bash /tmp/arp-upgrade.sh             # apply
  ```

  - **Backs up** `.claude/` → `.claude.pre-upgrade-<oldversion>/` (auto-gitignored).
  - **Regenerates** template-owned config for the stamped profile + flags: `settings.json`, `skills/ agents/ hooks/ templates/ commands/`, profile rules, `refresh-skills.sh`.
  - **Preserves** `settings.local.json`, `rules/project-conventions.md`, `.claude/CLAUDE.md`, `audit.log`, `session-reports/`.
  - **Bumps the stamp** and prints the CHANGELOG delta.
  - No-op (exits 0, no backup) when already current. Refuses a repo with no stamp. `--ref vX.Y.Z` targets a version; `--dry-run` previews.

- **`/template-upgrade`** slash command (new). Runs the same flow from inside a session and guides the agent through reconciling any custom `settings.json` entries against the CHANGELOG (removed-by-template vs your-customization).

- **`settings.json` is regenerated, not merged.** A union merge would re-add entries the template deliberately removed (e.g. the deprecated `Write(path)` denies dropped in v0.1.19). Overrides belong in `settings.local.json` (preserved). If you edited `settings.json` directly, the upgrader reports each custom entry so you can relocate it.

- **`init.sh` removes `upgrade.sh`** from a repo it initializes (same as `bootstrap.sh` — you always fetch a fresh `upgrade.sh`, never run a committed stale copy). The `/template-upgrade` command *does* ship into the repo. Template `.gitignore` now ignores `.claude.pre-upgrade-*/`.

### Why

Fresh init (`bootstrap.sh`) and staleness detection (`/template-check`) existed, but there was no safe way to *apply* an update — the manual cherry-pick flow was the only option, and `bootstrap.sh --force` clobbers user files with no backup. `upgrade.sh` closes the loop: check → upgrade, both one command.

### Tests

11 new assertions: `upgrade.sh` ships + executable, `/template-upgrade` command ships + survives init, `init.sh` removes `upgrade.sh`, functional upgrade of an old-stamped repo (stamp bumps, `project-conventions.md` + `settings.local.json` preserved, backup created, custom `settings.json` entry reported, regenerated settings drops the direct custom deny), no-op when current, refuses a stampless repo. 192 tests total, all green.

---

## [v0.1.19] — 2026-07-18

Fix: drop deprecated `Write(path)` permission-deny rules — clears the `/doctor` startup warnings on Claude Code v2.1.210+.

### What changed

- **Removed 19 `Write(<path>)` entries** from the base `settings.json` deny list. As of Claude Code **v2.1.210**, only `Edit(path)` and `Read(path)` rules are matched by file-permission checks, and `Edit(path)` covers **all** file-editing tools (`Edit`, `Write`, `NotebookEdit`). Standalone `Write(path)` rules are no longer honored and each threw a startup warning:

  > `Write(~/.ssh/**) is not matched by file permission checks — only Edit(path) rules are. Use Edit(~/.ssh/**) instead.`

  Every removed `Write(<path>)` already had an `Edit(<path>)` twin in the deny list, so **protection is unchanged** — the `Edit(...)` rule blocks both the Edit and Write tools. Deny list: 62 → 43 entries; all 19 sensitive-path `Edit(...)` denies retained (ssh, aws, gnupg, kube, gcloud, gitconfig, npmrc, pypirc, docker, netrc, gh, shell init files, `~/.claude/settings.json`, `~/.claude.json`).

- **`rules/autonomous-work.md`**: new section documenting that file-permission denies use `Edit(path)` (not `Write(path)`), why one `Edit(...)` rule is sufficient, and that sandboxed-shell reads are guarded separately (`sandbox.filesystem.denyRead` / `sandbox.credentials`).

### Migration for existing repos

Edit `.claude/settings.json` and delete the `Write(...)` lines from `permissions.deny` (keep the `Edit(...)` lines). Or re-run `init.sh <profile>` from a v0.1.19 clone / `bootstrap.sh --force`. No protection is lost — the warnings just go away.

### Also noted from the Claude Code v2.1.114 → v2.1.214 changelog (no template change required)

- **v2.1.212** — subagents inherit the session's permission mode; the Task `mode` parameter is deprecated. We don't set it. No change.
- **v2.1.195** — hook matchers with hyphens (e.g. `code-reviewer`) are now exact-match, not substring. Our hooks use no hyphenated matchers. No change.
- **v2.1.200** — the default permission mode was renamed "default" → "Manual". We don't set `defaultMode`. No change.
- **v2.1.183/191** — new `sandbox.credentials` setting blocks sandboxed commands from reading credential files + env vars. A genuine complement to our `sandbox.filesystem.denyRead`; evaluated as a candidate for a future release once its exact `{files, envVars}` semantics are pinned down. Not adopted in v0.1.19.

### Tests

8 new assertions: no `Write()`/`NotebookEdit()`/`Glob()` path rules anywhere in `permissions`; each of the 7 spot-checked sensitive paths still has an `Edit(...)` deny. 177 tests total, all green.

---

## [v0.1.18] — 2026-06-26

New: `bootstrap.sh` — one-command init for an existing directory.

### What changed

- **`bootstrap.sh`** (new, repo root) — drops the template's `.claude/` tree (and `.gitignore`, if you don't already have one) into the *current* directory and runs `init.sh <profile>`, in one command. Works in any directory: empty or with content, git repo or not. This is the supported equivalent of the manual "clone the template, copy `.claude/`, run `init.sh`, clean up" dance.

  ```bash
  # inspect-first (recommended)
  curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh -o /tmp/arp-bootstrap.sh
  bash /tmp/arp-bootstrap.sh research

  # one-liner (auto-executes remote code — trust the source)
  curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh | bash -s -- research
  ```

  Flags: `--ref vX.Y.Z` (pin a version; default `main` = latest release), `--force` (overlay an existing `.claude/` — refused by default to avoid clobbering a configured repo), and pass-throughs `--cloud-compat` / `--strict-sandbox` / `--dry-run` → `init.sh`.

- **`init.sh` removes `bootstrap.sh`** from a repo it initializes (consistent with how it resets the template README and deletes the template CHANGELOG) — `bootstrap.sh` is tooling for setting up *other* directories, not project content. The "Use this template" flow ships it at root; running `init.sh` cleans it up.

### Why

"Use this template" creates a new GitHub repo; it doesn't help when you want the config in an existing local or remote directory. That case (drop into an arbitrary dir) had no first-class command — `bootstrap.sh` fills it.

### Notes

- `bootstrap.sh` honors an `ARP_BOOTSTRAP_SOURCE` env var (local directory or alternate git URL) so forks and the test suite can point it somewhere other than the public repo.
- No profile-content change. Rules, skills, settings, hooks are identical to v0.1.17.

### Tests

10 new assertions: `bootstrap.sh` ships + is executable; bootstrapping a fresh dir produces a valid init (settings + stamp + knowledge-work rule present, `.gitignore` seeded, `profiles/` self-cleaned); the no-clobber guard refuses a second run without `--force`; an existing `.gitignore` is not overwritten; `init.sh` removes `bootstrap.sh` from an initialized repo. 169 tests total, all green. (`bootstrap.sh` is also clean under `shellcheck`.)

---

## [v0.1.17] — 2026-06-25

New rule: standardized knowledge-work directory structure for research-tier profiles.

### What changed

- **`research/rules/knowledge-work-structure.md`** (new) — ships in `research`, `paper`, and `paper-latex` (inherited via the research chain). Encodes a standing convention for organizing knowledge work into top-level directories:
  - `research/` — research output (yours, subagents', workflows'); subdirs when justified.
  - `papers/` — research papers you download; maintain `papers/INDEX.md` (filename, title, authors, year/venue, DOI/URL, one-line relevance) so the collection stays navigable.
  - `input/` — raw documents the user provides.
  - `insights/` — conclusions formed jointly with the user.
  - `deliverables/` — documents produced for the user or external people.
  - `questions/` — open questions (esp. multi-expert projects), kept as living documents with answers updated as work progresses.
- **Lazy creation** — directories are made the first time they're needed, not scaffolded empty at init. No `init.sh` behavior change; the rule loads every session (no `paths:` frontmatter) for research-tier profiles.

### Why

This convention was a prompt the template author re-typed at the start of every knowledge-work repo. Baking it into the `research` profile makes it a default instead of a manual first step.

### Post-init rule counts

| Profile | v0.1.16 | v0.1.17 |
|---|---:|---:|
| `info` | 9 | 9 |
| `research` | 12 | 13 |
| `paper` | 16 | 17 |
| `paper-latex` | 20 | 21 |
| `code` | 13 | 13 |

`info` and `code` are unaffected — knowledge-work structure is research-tier only. (v0.1.16 was the MCP permission-allow-list fix — see its entry above; it did not change rule counts.)

### Tests

5 new assertions (one per profile in the e2e loop): rule ships in research / paper / paper-latex, and is absent from info / code. 159 tests total, all green.

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
