# agentic-repo-template — Design Spec

**Date:** 2026-04-15
**Status:** approved design, ready for implementation plan

## 1. Overview

A GitHub template repository that lets the user spin up a new project with sane Claude Code defaults for autonomous work. The template ships a base `.claude/` configuration plus four profile overlays — `info`, `research`, `paper`, `code` — applied via a single init script. After init, the profile's files are merged into place and the scaffolding (`init.sh`, `profiles/`) self-removes, leaving a clean repo.

The design is evidence-based: 2,495 sessions across the user's Mac laptop and 1,014 sessions from the `magent` VM (190,247 tool invocations total, Jan–Apr 2026) were analyzed to determine which plugins, skills, MCP servers, and subagents the user actually uses. Plugins shown to be dead weight in practice were dropped; plugins shown to earn their weight were kept; plugins unused anywhere were not added.

## 2. Goals

1. **Minimize permission prompts during autonomous work.** A session using this template should run hands-off in the vast majority of cases. The sandbox, deny list, and correct wildcard syntax are the three enforcement layers.
2. **Match the user's revealed workflows.** Ship what gets used; drop what doesn't.
3. **Stay mixed-use.** The template is not specialized for a language or framework. Code-heavy work that demands, e.g., a TypeScript-specific reviewer pipeline gets a separate template; this one is the umbrella.
4. **Clean result after init.** The user should not see template scaffolding in their final repo. No `profiles/`, no `init.sh`.
5. **Self-maintaining skill vendoring.** Skills are vendored at init time (offline-deterministic), and a `refresh-skills.sh` helper stays in the project so the user can re-pull upstreams later.

### Non-goals

- A generator for code repositories with language-specific tooling (Go, TypeScript, Python). Those are separate specialized templates.
- A GitHub Actions CI pipeline. Deferred to a later iteration.
- `.github/` issue/PR templates. Deferred.
- A snapshot-branches CI that auto-regenerates `snapshot/info`, `snapshot/research`, etc. Deferred; may add later if "pick a branch, done" UX matters.

## 3. Architecture

Single base tree + four profile overlays + one init script.

```
agentic-repo-template/          (the template as cloned)
├── CLAUDE.md                   (root stub; becomes project CLAUDE.md after init)
├── README.md                   (how to use the template)
├── LICENSE                     (MIT by default)
├── .gitignore
└── .claude/
    ├── settings.json           (base)
    ├── CLAUDE.md               (base; profile CLAUDE.append.md appended on init)
    ├── rules/                  (3 base rule files)
    ├── audit.log               (empty; appended by ConfigChange hook)
    ├── session-reports/
    │   └── .gitkeep
    ├── init.sh                 (applies the chosen profile; self-removes)
    ├── refresh-skills.sh       (stays in .claude/ post-init)
    └── profiles/               (deleted by init.sh after apply)
        ├── info/
        ├── research/
        ├── paper/
        └── code/
```

### Distribution

Public GitHub template repository. User creates a new repository from it via GitHub's "Use this template" button, clones locally, and runs `./.claude/init.sh <profile>`.

### Profile inheritance

- `info` → base (no parent)
- `research` → extends `info`
- `paper` → extends `research`
- `code` → extends `info` directly (does **not** extend `research`; code work has no citation discipline overhead)

`init.sh` walks the extends-chain outermost-first, applying each overlay in order.

## 4. Base `.claude/` configuration

### settings.json

Baseline choices (evidence: state-of-the-art docs as of 2026-04-15, CHANGELOG v2.1.70–v2.1.109):

```jsonc
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "alwaysThinkingEnabled": true,
  "enableAllProjectMcpServers": false,
  "env": {
    "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1",
    "ENABLE_LSP_TOOL": "1"
  }
}
```

### permissions

Wildcard allow (bare tool names, per JSON schema regex — `Bash(*)` and `WebFetch(*)` are schema-invalid and lint-noisy; bare names are canonical):

```jsonc
"permissions": {
  "allow": [
    "Bash", "Read", "Write", "Edit", "Glob", "Grep",
    "WebFetch", "WebSearch", "Agent", "mcp__*"
  ],
  "deny": [
    // --- Bash: destructive commands ---
    "Bash(sudo *)", "Bash(rm -rf /)",
    "Bash(docker push *)",
    "Bash(git push --force*)", "Bash(git push * --force*)",
    "Bash(git push -f)", "Bash(git push -f *)",
    "Bash(git push * -f)", "Bash(git push * -f *)",
    "Bash(git commit --no-verify *)", "Bash(git commit -n *)",

    // --- Read: private material (reading into model context is the leak) ---
    "Read(~/.ssh/id_*)", "Read(~/.ssh/*.pem)",
    "Read(~/.aws/**)", "Read(~/.gnupg/**)",
    "Read(~/.kube/**)", "Read(~/.config/gcloud/**)",
    "Read(~/.npmrc)", "Read(~/.pypirc)",
    "Read(~/.docker/config.json)", "Read(~/.netrc)",
    "Read(~/.config/gh/**)",
    "Read(~/.bash_history)", "Read(~/.zsh_history)",

    // --- Edit/Write: privilege escalation + persistence vectors ---
    // Claude's own user-level config (MUST be protected: could widen perms)
    "Write(~/.claude.json)", "Edit(~/.claude.json)",
    "Write(~/.claude/settings.json)", "Edit(~/.claude/settings.json)",

    // Credential/config dirs (tampering rewrites registries, auth, etc.)
    "Write(~/.ssh/**)", "Edit(~/.ssh/**)",
    "Write(~/.aws/**)", "Edit(~/.aws/**)",
    "Write(~/.gnupg/**)", "Edit(~/.gnupg/**)",
    "Write(~/.kube/**)", "Edit(~/.kube/**)",
    "Write(~/.config/gcloud/**)", "Edit(~/.config/gcloud/**)",
    "Write(~/.gitconfig)", "Edit(~/.gitconfig)",
    "Write(~/.npmrc)", "Edit(~/.npmrc)",
    "Write(~/.pypirc)", "Edit(~/.pypirc)",
    "Write(~/.docker/config.json)", "Edit(~/.docker/config.json)",
    "Write(~/.netrc)", "Edit(~/.netrc)",
    "Write(~/.config/gh/**)", "Edit(~/.config/gh/**)",

    // Shell init (persistence)
    "Write(~/.bashrc)", "Edit(~/.bashrc)",
    "Write(~/.zshrc)", "Edit(~/.zshrc)",
    "Write(~/.profile)", "Edit(~/.profile)",
    "Write(~/.bash_profile)", "Edit(~/.bash_profile)",
    "Write(~/.zprofile)", "Edit(~/.zprofile)",
    "Write(~/.zshenv)", "Edit(~/.zshenv)"
  ]
}
```

Evaluation order is deny → ask → allow; first match wins. A bare `WebFetch` allows every domain without per-host prompts (user requirement, captured in auto-memory).

### sandbox

Defense in depth under the permission system. Matches the pattern convergent across 32 of the user's existing repos, with two new primitives from v2.1.83:

```jsonc
"sandbox": {
  "enabled": true,
  "autoAllowBashIfSandboxed": true,
  "allowUnsandboxedCommands": true,
  "failIfUnavailable": true,
  "excludedCommands": [
    "ssh:*", "scp:*", "rsync:*", "devbox:*",
    "nix:*", "git:*", "gpg:*", "gpg-agent:*"
  ],
  "network": { "allowedDomains": ["*"] },
  "filesystem": {
    "allowWrite": [
      "~/.cache/devbox", "~/.local/share/devbox",
      "~/.nix-profile", "/nix"
    ],
    "denyWrite": [
      "/etc", "/usr", "/bin", "/sbin",
      "~/.ssh", "~/.aws", "~/.bashrc", "~/.zshrc"
    ],
    "denyRead": [
      "~/.aws", "~/.kube", "~/.config/gcloud",
      "~/.ssh/id_*", "~/.ssh/*.pem"
    ]
  }
}
```

### enabledPlugins

Eight baseline plugins, kept across every profile:

```jsonc
"enabledPlugins": {
  "superpowers@claude-plugins-official": true,
  "commit-commands@claude-plugins-official": true,
  "claude-md-management@claude-plugins-official": true,
  "session-report@claude-plugins-official": true,
  "hookify@claude-plugins-official": true,
  "claude-code-setup@claude-plugins-official": true,
  "feature-dev@claude-plugins-official": true,
  "elements-of-style@superpowers-marketplace": true
}
```

Evidence for each:

| Plugin | Evidence |
|---|---|
| superpowers | 113+ skill invocations combined; brainstorming (85) and writing-plans (52) dominate |
| commit-commands | Low direct invocation but streamlines commits across all work types; low cost |
| claude-md-management | Autonomous work requires good project memory; this plugin maintains it |
| session-report | Manual skill: `/session-report`. Reads JSONL transcripts from disk (live or archived by the PreCompact hook) and generates narrative analytics. Not hook-invoked — the plugin's own behavior is transcript-file-based, and `type: prompt` hooks cannot instruct the main agent to run skills. |
| hookify | User-requested; meta-tool for customizing automation post-clone |
| claude-code-setup | User-requested; helps onboard new repos created from the template |
| feature-dev | 128 combined subagent dispatches (`code-reviewer` 114, `code-explorer` 14) |
| elements-of-style | Strunk & White + banned-AI-phrase rules; highest leverage for knowledge work |

Dropped from the user's historical baseline based on evidence:

| Plugin | Evidence for dropping |
|---|---|
| everything-claude-code | 3 skill invocations + 15 subagent dispatches across 190K tool calls (≤ 0.01%) |
| holistic-linting | 0 invocations across 190K tool calls |
| security-guidance | User preference (no objective evidence against) |
| explanatory-output-style | User preference (explicit opt-in preferred over ambient style change) |
| code-review | 0 explicit Skill invocations; feature-dev + superpowers cover the role |

Marketplace registration: two marketplaces are referenced — `claude-plugins-official` (for the first seven plugins) and `superpowers-marketplace` (for `elements-of-style`). The template declares both in its marketplace configuration so all plugins resolve on first launch without manual setup. The exact settings.json key for marketplace declaration is verified against the schema at implementation time.

### hooks

Three hooks, all from the base:

```jsonc
"hooks": {
  "SessionStart": [
    { "hooks": [
      { "type": "command",
        "command": "echo \"Branch: $(git branch --show-current 2>/dev/null || echo detached). Recent: $(git log --oneline -3 2>/dev/null || echo no-commits)\"",
        "timeout": 5000 }
    ]}
  ],
  "ConfigChange": [
    { "hooks": [
      { "type": "command",
        "command": "printf '%s\\t%s\\t%s\\n' \"$(date -u +%FT%TZ)\" \"$(git config user.email 2>/dev/null || echo -)\" \"${CLAUDE_HOOK_FILE:-?}\" >> \"$CLAUDE_PROJECT_DIR/.claude/audit.log\"" }
    ]}
  ],
  "PreCompact": [
    { "hooks": [
      { "type": "command",
        "command": "sh -c 'mkdir -p \"$CLAUDE_PROJECT_DIR/.claude/session-reports\"; TS=$(date -u +%Y%m%dT%H%M%SZ); [ -n \"$CLAUDE_TRANSCRIPT_PATH\" ] && cp \"$CLAUDE_TRANSCRIPT_PATH\" \"$CLAUDE_PROJECT_DIR/.claude/session-reports/${TS}-precompact-transcript.jsonl\" 2>/dev/null; { echo \"# Pre-compact $TS\"; git -C \"$CLAUDE_PROJECT_DIR\" status -sb; echo; git -C \"$CLAUDE_PROJECT_DIR\" log --oneline -10; } > \"$CLAUDE_PROJECT_DIR/.claude/session-reports/${TS}-precompact-gitstate.md\"; echo \"[PreCompact] Context compaction imminent. Transcript archived at .claude/session-reports/${TS}-precompact-transcript.jsonl — run /session-report for a narrative summary before history is compressed.\" >&2'",
        "timeout": 30000 }
    ]}
  ],
  "SessionEnd": [
    { "hooks": [
      { "type": "command",
        "command": "sh -c 'mkdir -p \"$CLAUDE_PROJECT_DIR/.claude/session-reports\"; TS=$(date -u +%Y%m%dT%H%M%SZ); { echo \"# Session end $TS\"; git -C \"$CLAUDE_PROJECT_DIR\" status -sb; echo; git -C \"$CLAUDE_PROJECT_DIR\" log --oneline -10; } > \"$CLAUDE_PROJECT_DIR/.claude/session-reports/${TS}-session-end.md\"'",
        "timeout": 10000 }
    ]}
  ]
}
```

Hook rationales:

- **SessionStart**: 6/32 of the user's existing repos do this; cheap context.
- **ConfigChange** (shipped v2.1.105): auditability — appends to `.claude/audit.log`, which is committed to git. Every change Claude makes to its own config becomes a git-reviewable signal.
- **PreCompact** (shipped v2.1.105): `type: command` only. Archives the full session transcript JSONL (`$CLAUDE_TRANSCRIPT_PATH`) plus a git-state snapshot under `.claude/session-reports/` at the moment compaction is about to fire. Zero token cost to the main context; runs as a plain shell command outside the model. Does **not** attempt to invoke `/session-report` via a `type: prompt` hook — research established that prompt hooks run as separate Haiku evaluations and cannot instruct the main agent to execute a skill. A separate hook would therefore have been silent-failure-prone. The archived JSONL preserves the full pre-compaction history so `/session-report` (a manual skill invocation) can analyze it afterward if a narrative report is wanted.
- **SessionEnd** (session-level): captures git state once when the session closes. Unlike per-turn `Stop`, this fires exactly once per session. Useful for async review — you return to a repo, read the latest `*-session-end.md`, and see the final state.
- **`CLAUDE_TRANSCRIPT_PATH`** availability in PreCompact hooks was fixed in v2.1.105 (was empty in earlier versions per GitHub issue #13668). The template README documents v2.1.105+ as minimum Claude Code version.

### Base files

| File | Purpose |
|---|---|
| `.claude/CLAUDE.md` | Stub with placeholder sections (Project Overview, Build/Test, Common Tasks) |
| `.claude/rules/autonomous-work.md` | Behavior rules when Claude operates unattended |
| `.claude/rules/pr-discipline.md` | Commit message format, PR structure, when to open |
| `.claude/rules/project-conventions.md` | Placeholder for per-project overrides |
| `.claude/audit.log` | Empty file committed to git; ConfigChange hook appends |
| `.claude/session-reports/.gitkeep` | Committed empty dir |

## 5. Profiles

Each profile directory contains:

```
profiles/<name>/
├── settings.overlay.json       # deep-merged into .claude/settings.json
├── CLAUDE.append.md            # appended to .claude/CLAUDE.md
├── rules/                      # copied into .claude/rules/
├── skills/                     # copied into .claude/skills/ (if present)
└── skills.manifest.json        # declares skill sources (for refresh-skills.sh)
```

### Profile contents

Profiles only add plugins, rules, and skills. They do not change permissions, sandbox, hooks, or env — those are base.

| Capability | info | research | paper | code |
|---|:-:|:-:|:-:|:-:|
| **Plugins** | base 8 | base 8 + context7 | base 8 + context7 | base 8 + context7 |
| **Rules added** | writing-quality | + citation-discipline, + reading-before-editing | + latex-bibtex-discipline, + humanize-prose | + makefile-conventions, + devbox-usage, + testing-discipline, + verification-before-done |
| **Vendored skills** | — | — | humanizer, analyze-paper | — |
| **External reqs documented** | — | Scholar Gateway claude.ai connector | Scholar Gateway + Google Scholar fallback | `/configure-ecc` recommendation; devbox |

Total rules per profile after inheritance: info=4, research=6, paper=8, code=8.

### Vendoring details

- **`humanizer`**: upstream `github.com/groundnuty/humanizer.git` v2.1.1. Vendored into `profiles/paper/skills/humanizer/` with the `.git` directory stripped. `skills.manifest.json` records the upstream URL so `refresh-skills.sh` can pull updates later.
- **`analyze-paper`**: vendored from `papers/ccgrid2026/.claude/skills/analyze-paper/`, generalized to remove ccgrid2026-specific references. No upstream; marked as `source: "local"` in the manifest.

### Scholar Gateway handling

Scholar Gateway is a **claude.ai-hosted connector**, not a local MCP process. The template cannot ship it. The `research` and `paper` profile `CLAUDE.append.md` files document:

1. Enable the Scholar Gateway connector in claude.ai settings (one-time, per-account).
2. Complement with WebSearch on Google Scholar for conference proceedings (Scholar Gateway only indexes journal papers — a known gap already noted in the user's global CLAUDE.md).

Tool invocations are pre-approved via the `mcp__*` wildcard in `permissions.allow`.

## 6. `init.sh` design

Location: `.claude/init.sh`.

Signature: `./.claude/init.sh <info|research|paper|code> [--keep-profiles] [--dry-run]`.

### Behavior

1. Validate the profile argument against the set `{info, research, paper, code}`.
2. Compute the extends-chain (e.g., `paper` → `research` → `info`).
3. For each profile in the chain, outermost-first:
   - Deep-merge `profiles/<name>/settings.overlay.json` into `.claude/settings.json` using `jq`. Arrays concatenate (for permission/allow lists, enabledPlugins), objects merge.
   - Append `profiles/<name>/CLAUDE.append.md` to `.claude/CLAUDE.md`.
   - Copy `profiles/<name>/rules/*.md` into `.claude/rules/`.
   - Copy `profiles/<name>/skills/*/` into `.claude/skills/`.
   - Merge `profiles/<name>/skills.manifest.json` entries into `.claude/skills.manifest.json` (for `refresh-skills.sh`).
4. Unless `--keep-profiles`, remove `profiles/` and `init.sh` itself.
5. Print a summary: profile applied, rules added, skills vendored, plugins enabled.

### Dependencies

- `bash` (POSIX-compatible), `jq` (for deep-merge), `cp`, `rm`, `cat`, `find`.
- `jq` is widely available; documented as a prerequisite in README.
- No network required.

### Error modes

- Unknown profile argument → exit 2, print usage.
- `jq` not on `PATH` → exit 3, actionable message.
- `.claude/` or `profiles/` missing → exit 4, actionable message (template corrupted or init already run).

### Dry run

`--dry-run` prints every action without mutating the filesystem.

## 7. `refresh-skills.sh` design

Location: `.claude/refresh-skills.sh` (stays post-init).

Signature: `./.claude/refresh-skills.sh [<skill-name>]`.

### Behavior

1. Read `.claude/skills.manifest.json`.
2. For each entry with `source: "git"` and an `upstream` URL:
   - `git clone --depth 1 --branch <ref> <url>` into a temp directory.
   - Strip `.git` from the cloned copy.
   - Replace `.claude/skills/<name>/` with the fresh content.
3. For entries with `source: "local"`, skip (they have no upstream).
4. Optional argument restricts refresh to a single named skill.

### Error modes

- Network unreachable → exit 2, actionable message; leaves existing skill in place.
- Skill not in manifest → exit 3.
- `git` not on `PATH` → exit 4.

## 8. Root scaffolding

| File | Purpose |
|---|---|
| `CLAUDE.md` | Project-root stub. May `@import` `.claude/CLAUDE.md`. |
| `README.md` | Template usage: "Use this template → clone → run `./.claude/init.sh <profile>`". Includes profile comparison table. |
| `LICENSE` | MIT by default. Documented as swappable. |
| `.gitignore` | Multi-language with strong secret-pattern block: `.env*`, `*.pem`, `*.key`, `*.p12`. Plus `.claude/settings.local.json`, `.claude/.cache/`. |

## 9. Security & autonomous-work considerations

### The layered defense model

The template's security is layered. Each layer has a distinct scope and known limits. Understanding which layer catches what prevents false confidence.

| Layer | What it filters | Scope limit |
|---|---|---|
| `permissions.deny` | Command-line strings Claude **directly invokes** | Does not see inside scripts, Makefile recipes, or subprocess-of-subprocess chains |
| `sandbox.filesystem` | OS-level read/write from Bash subprocesses | Does not apply to `excludedCommands` (git, ssh, scp, devbox, nix, gpg) which run unsandboxed |
| `sandbox.network` | Outbound network from Bash subprocesses | Does not apply to WebFetch (runs outside the sandbox) |
| `.gitignore` | What gets committed | Does not prevent secret exposure at runtime, only in git history |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` | Credentials in subprocess environment | Does not strip credentials embedded in files or passed as args |

**Consequences worth stating explicitly:**

- A deny pattern like `Bash(rm -rf /)` catches only the literal string. A destructive script (e.g., `./deploy.sh` with `rm -rf $UNSET_VAR` expanding to `rm -rf `) is not caught at the permission layer. The sandbox's `denyWrite` on `/etc /usr /bin /sbin` is what actually limits damage from such scripts, and only for paths inside the sandbox guard.
- Deny patterns like `Bash(make push *)` or `Bash(make deploy *)` are **cargo-cult**: if `make push` wraps `git push`, the `git push --force*` patterns already handle the real hazard whether invoked directly or via make. If `make deploy` does something else destructive, a pattern on the target name still doesn't prevent the action inside the recipe. The template deliberately does not ship these to avoid false confidence.
- `git` is in `sandbox.excludedCommands` (so it runs unsandboxed with full filesystem access). The defense against destructive git is the `git push --force*` and `git commit --no-verify` patterns, plus user review of diffs before merge.

### Specific choices

- **Bare-tool-name allow is the only syntactically correct wildcard.** JSON schema regex `(?=.*[^)*?])` inside the argument position rejects `Bash(*)` and `WebFetch(*)`. Documented so future maintenance doesn't reintroduce the lint-noisy form.
- **Force-push denied, normal push allowed.** `git push` is auto-approved so autonomous agents can ship their work; `git push --force` / `-f` / `--force-with-lease` are blocked as the real hazard (history rewrites).
- **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`** strips Anthropic + cloud-provider credentials from every Bash subprocess, hook, and MCP stdio server. The realistic blast-radius limiter for prompt-injection-driven subprocess execution.
- **`audit.log`** is committed to git. Every modification to `.claude/*` appends a line; after an autonomous session, `git diff` on `audit.log` is the trail.
- **`.gitignore` blocks `.env*` / `*.pem` / `*.key`.** Complements the permission deny list: deny list prevents Claude from *reading* `~/.ssh` material; `.gitignore` prevents project-local secrets from being *committed*.
- **`sandbox.failIfUnavailable: true`** ensures sessions don't silently degrade to unsandboxed mode when the OS sandbox is unavailable.

### Why Edit/Write denies matter even though sandbox blocks writes outside CWD

The sandbox default policy blocks Bash subprocess writes outside the current working directory. However, Claude's built-in `Read`, `Edit`, and `Write` tools **bypass the sandbox entirely** — they are governed by the permission system only. Without explicit `Edit(...)` and `Write(...)` deny entries for sensitive paths, an agent could directly modify `~/.claude.json`, `~/.ssh/authorized_keys`, or `~/.gitconfig` using the `Edit` tool — widening its own permissions, installing a persistence hook, or changing git internals — regardless of sandbox configuration. The deny list above closes this gap.

### Escape hatch: `settings.local.json`

The template deliberately ships **strict** denies across the board (no `ask` tier in the baseline). Legitimate occasional needs — editing your own `~/.claude.json`, running `aws configure`, debugging a failing SSH profile — are not baseline workflows for autonomous agents and should not be pre-approved in a template that ships to others.

The standard escape hatch is `~/.claude/settings.local.json` or `.claude/settings.local.json`:
- Gitignored (entry is in the template's `.gitignore`).
- Merges with `settings.json` at load time (arrays concatenate).
- A user who knows they need e.g. `"ask": ["Edit(~/.gitconfig)"]` or `"allow": ["Read(~/.aws/**)"]` for a specific project adds it locally, and it stays out of git history.
- No shipped `settings.local.json.example` — deliberately keep the template surface minimal. The escape hatch is documented in `README.md`.

## 10. Testing

- **Schema check**: every `settings.json` (base + each profile's settings.overlay.json merged) validates against `https://json.schemastore.org/claude-code-settings.json`.
- **Init-script end-to-end**: for each profile, run `./.claude/init.sh <profile>` in a throwaway directory. Verify: expected files present, no `profiles/` or `init.sh` left, settings.json parses and matches expected shape.
- **Dry-run**: `./.claude/init.sh <profile> --dry-run` produces identical output in all environments (deterministic).
- **refresh-skills**: vendor a small fixture-skill with an upstream pointer, verify refresh pulls and strips `.git`.
- **Permission rule regex**: test that `Bash`, `WebFetch`, etc. in allow parse as the bare-tool-name form (no parenthesized argument).

## 11. Out of scope / deferred

- Language-specific tooling (Go / TS / Python scaffolding). Separate templates.
- GitHub Actions CI workflows. Deferred.
- `.github/` issue and PR templates. Deferred.
- Snapshot branches auto-regenerated from overlays. Deferred; add if "pick a branch" UX becomes valuable.
- `configure-ecc` automation. Documented as a recommended manual step in the `code` profile's `CLAUDE.append.md`.
- Additional profiles (e.g., `infra` for kubernetes/terraform work, `ml` for notebooks). Out of v1 scope.

## 12. References

- JSON schema: https://json.schemastore.org/claude-code-settings.json
- Permissions docs: https://code.claude.com/docs/en/permissions
- Sandboxing docs: https://code.claude.com/docs/en/sandboxing
- Hooks docs: https://code.claude.com/docs/en/hooks
- Headless docs: https://code.claude.com/docs/en/headless
- CHANGELOG (window 2026-02-15 → 2026-04-15): https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
- Empirical usage analysis: this session's research agents, 190,247 tool invocations across 3,509 sessions.
- humanizer upstream: https://github.com/groundnuty/humanizer.git v2.1.1
- analyze-paper source: `papers/ccgrid2026/.claude/skills/analyze-paper/`
