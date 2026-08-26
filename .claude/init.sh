#!/usr/bin/env bash
#
# .claude/init.sh — apply a profile overlay to the base template.
#
# Usage:
#   ./.claude/init.sh <info|research|paper|paper-latex|code> [--strict-sandbox] [--keep-profiles] [--dry-run]
#   ./.claude/init.sh --cloud-compat                                            [--dry-run]   (deprecated)
#
# Deep-merges profiles/<profile>/settings.overlay.json into .claude/settings.json,
# copies rule files and skill dirs, appends CLAUDE.append.md to .claude/CLAUDE.md,
# merges skills.manifest.json entries, installs the profile's capability plugins
# (v0.3), then removes profiles/ and init.sh.
#
# With --cloud-compat (no profile), runs in patch-only mode against an already-
# initialized .claude/settings.json — useful for upgrading existing repos to be
# compatible with Claude Code on the web's nested sandbox.
#
# Environment:
#   ARP_SKIP_PLUGIN_INSTALL=1  Do not run `claude plugin ...`; print the exact
#                              commands and a warning instead. Used by the test
#                              suite, by upgrade.sh's throwaway $WORK init, and
#                              by offline / air-gapped initializations.
#   ARP_MARKETPLACE_SOURCE     Override the marketplace source (tests point this
#                              at a local marketplace directory).

set -eu

VALID_PROFILES=(info research paper paper-latex code)
JQ="${JQ:-jq}"
TEMPLATE_VERSION="v0.4.6"

# --- capability plugins (v0.3) ------------------------------------------------
# A profile "declares" a plugin by carrying <name>@$MARKETPLACE_NAME in the
# enabledPlugins of its settings overlay. A committed declaration alone is a
# SILENT NO-OP (spike U6): the marketplace registers, the plugin never arrives,
# nothing errors. So init.sh must also add+install+verify — see ensure_plugins.
MARKETPLACE_NAME="${ARP_MARKETPLACE_NAME:-agentic-plugins}"
MARKETPLACE_SOURCE="${ARP_MARKETPLACE_SOURCE:-groundnuty/agentic-plugins}"

# Payload the agentic-paper plugin now ships. These profile-relative paths are
# NEVER file-copied into .claude/ for a profile that declares the plugin: a
# stale scaffold copy silently WINS over the plugin on a bare-name collision
# (Phase-0 D5, arm 3), so shipping both is a correctness bug, not duplication.
# The files stay in profiles/ so an --ref-pinned older install still resolves
# them and so the payload's provenance stays in one tree.
PLUGIN_SUPERSEDED_PATHS="
skills/review-paper
skills/verify-claims
skills/proofread
skills/seven-pass-review
skills/respond-to-referees
skills/audit-reproducibility
skills/analyze-paper
skills/humanizer
skills/tikz
skills/validate-bib
agents/claim-verifier.md
agents/domain-referee.md
agents/editor.md
agents/methods-referee.md
agents/proofreader.md
rules/tikz-snippets
templates/response-to-referees.md
"

usage() {
  cat <<EOF
Usage:
  ./.claude/init.sh <info|research|paper|paper-latex|code> [--strict-sandbox] [--keep-profiles] [--dry-run]
  ./.claude/init.sh --cloud-compat [--dry-run]   (deprecated; see below)

Applies a profile overlay to the base .claude/ tree.

Profiles:
  info         Pure information work — reports, document analysis, no code.
  research     Technical research — reading docs, light code analysis, no code writing.
  paper        Academic paper / manuscript writing — prose polishing, peer review,
               format-agnostic (works for LaTeX, Markdown, Word, Google Docs).
  paper-latex  Paper + LaTeX / BibTeX / TikZ layer. Apply when compiling with LaTeX.
  code         Code-centric work — Makefile/devbox/testing conventions.

Sandbox modes:
  Default (v0.1.15+):  cloud-safe. No sandbox.failIfUnavailable. Settings load
                       successfully on Claude Code on the web's nested-container
                       VM as well as locally.
  --strict-sandbox:    add sandbox.failIfUnavailable=true so Claude Code aborts
                       session-start when the OS sandbox cannot initialize. For
                       managed deployments where sandboxing is a security gate.

Other options:
  --cloud-compat   DEPRECATED in v0.1.15+. Was the v0.1.14 workaround for the
                   web sandbox. Base settings are now cloud-safe by default, so
                   this flag is a no-op for the failIfUnavailable patch. Still
                   prunes devbox/nix paths from sandbox.filesystem.allowWrite
                   (cosmetic; non-existent paths are inert anyway). Prints a
                   deprecation warning.
  --keep-profiles  Do not delete .claude/profiles/ and this script after apply.
  --dry-run        Print what would be done without mutating files.

Capability plugins (v0.3):
  Profiles whose merged settings declare <plugin>@${MARKETPLACE_NAME} get that
  plugin installed at PROJECT scope and verified for THIS repo. The payload the
  plugin ships is NOT file-copied. Set ARP_SKIP_PLUGIN_INSTALL=1 to print the
  commands instead of running them (offline inits, and the test suite).
EOF
}

is_valid_profile() {
  local candidate="$1"
  for p in "${VALID_PROFILES[@]}"; do
    [ "$p" = "$candidate" ] && return 0
  done
  return 1
}

resolve_chain() {
  local profile="$1"
  case "$profile" in
    info)     echo "info" ;;
    research) echo "info research" ;;
    paper)    echo "info research paper" ;;
    paper-latex) echo "info research paper paper-latex" ;;
    code)     echo "info code" ;;
    *)        echo "unknown" ; return 1 ;;
  esac
}

preflight() {
  if ! command -v "$JQ" >/dev/null 2>&1; then
    echo "error: jq not found on PATH (looked for '$JQ'). Install jq and re-run." >&2
    exit 3
  fi
  if [ ! -f .claude/settings.json ]; then
    echo "error: .claude/settings.json missing. Is this the template root?" >&2
    exit 4
  fi
  if [ ! -d .claude/profiles ]; then
    echo "error: .claude/profiles/ missing. Has init.sh already been run?" >&2
    exit 4
  fi
}

apply_settings_overlay() {
  local profile_dir="$1"
  local overlay="$profile_dir/settings.overlay.json"
  [ -f "$overlay" ] || return 0

  local settings=".claude/settings.json"
  local tmp
  tmp=$(mktemp)

  # Deep-merge: arrays concatenate, objects merge recursively.
  "$JQ" --slurpfile overlay "$overlay" '
    def deep_merge(b):
      if (type == "object") and (b | type == "object")
      then reduce (b | keys_unsorted[]) as $k
             (.; .[$k] = (if (.[$k] | type) == "array" and (b[$k] | type) == "array"
                          then .[$k] + b[$k]
                          elif (.[$k] | type) == "object" and (b[$k] | type) == "object"
                          then .[$k] | deep_merge(b[$k])
                          else b[$k] end))
      else b end;
    deep_merge($overlay[0])
  ' "$settings" > "$tmp"

  mv "$tmp" "$settings"
}

canonicalize_settings() {
  # `claude plugin marketplace add|install` rewrite .claude/settings.json in an
  # UNSTABLE key order (Phase-0 measured three different orders and 162 churn
  # lines for one semantic addition). `jq -S` is idempotent and does not touch
  # arrays, so authoring + re-canonicalizing in that order keeps consumer diffs
  # to the semantic change alone.
  local settings=".claude/settings.json" tmp
  [ -f "$settings" ] || return 0
  command -v "$JQ" >/dev/null 2>&1 || return 0
  tmp=$(mktemp)
  if "$JQ" -S . "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
  fi
}

is_plugin_superseded() {
  # $1 = profile-relative path, e.g. "skills/humanizer" or "agents/editor.md"
  local rel="$1" p
  for p in $PLUGIN_SUPERSEDED_PATHS; do
    [ "$p" = "$rel" ] && return 0
  done
  return 1
}

copy_tree_entry() {
  # Merge-copy one entry. `cp -R dir dest/` NESTS when dest/dir already exists
  # (chained profiles all ship hooks/__pycache__), so directories are merged
  # via the trailing-dot form and files are copied straight over.
  local src="$1" dest="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
  else
    cp -R "$src" "$dest"
  fi
}

copy_profile_content() {
  local profile_dir="$1" skip_superseded="${2:-0}"
  local subdir entry base
  # Copy any of: rules/, skills/, agents/, hooks/, templates/ that exist in the
  # profile — minus anything the profile's capability plugin already ships.
  for subdir in rules skills agents hooks templates; do
    [ -d "$profile_dir/$subdir" ] || continue
    while IFS= read -r entry; do
      [ -n "$entry" ] || continue
      base="${entry##*/}"
      if [ "$skip_superseded" = "1" ] && is_plugin_superseded "$subdir/$base"; then
        continue
      fi
      # mkdir lazily: a profile whose whole subdir is plugin-superseded (paper's
      # agents/) must not leave an empty directory behind.
      mkdir -p ".claude/$subdir"
      copy_tree_entry "$entry" ".claude/$subdir/$base"
    done < <(find "$profile_dir/$subdir" -mindepth 1 -maxdepth 1)
  done
  # Root-level template files (e.g. .mcp.json.example): copied to the repo root.
  # Later profiles in the chain overwrite earlier ones (each ships a complete file).
  if [ -d "$profile_dir/root-files" ]; then
    cp -R "$profile_dir/root-files/." "./"
  fi
}

# Kept for backward-compat with older test expectations.
copy_rules_and_skills() {
  copy_profile_content "$1" "${2:-0}"
}

# --- capability-plugin declaration --------------------------------------------
# The declared set is DATA, read from settings — never a hardcoded profile list.
# Only ids from OUR marketplace are ours to install; @claude-plugins-official
# entries are Claude Code's own and are left alone.
plugins_declared_in() {
  local file="$1"
  [ -f "$file" ] || return 0
  "$JQ" -r --arg mkt "@$MARKETPLACE_NAME" \
    '(.enabledPlugins // {}) | keys[] | select(endswith($mkt))' "$file" 2>/dev/null || true
}

declared_plugins_for_chain() {
  local chain="$1" p
  for p in $chain; do
    plugins_declared_in ".claude/profiles/$p/settings.overlay.json"
  done | sort -u
}

# --- AGENTS.md: the cross-harness instruction file (v0.4.0) ---------------
# Codex and OpenCode read ONE instruction file, AGENTS.md, and ignore CLAUDE.md
# and .claude/rules/ entirely (verified empirically, 2026-07-29). Claude Code is
# the mirror image: it ignores AGENTS.md unless CLAUDE.md imports it.
#
# So the always-on rules are composed INTO AGENTS.md, and .claude/rules/ keeps
# only the path-scoped ones (no other harness has glob scoping). Claude reads the
# same bytes through the `@AGENTS.md` import in CLAUDE.md — one source, no
# duplication, no double-loading.
#
# The generated part is fenced. upgrade.sh replaces ONLY what is between the
# markers, so anything you add outside them survives (D49).
AGENTS_TMP=".agents-rules.tmp"
AGENTS_BEGIN="<!-- BEGIN template-managed — regenerated by upgrade; edits here are lost -->"
AGENTS_END="<!-- END template-managed -->"

rule_is_path_scoped() {
  sed -n '1,8p' "$1" 2>/dev/null | grep -q '^paths:'
}

# Move every always-on rule out of .claude/rules/ and into the managed region.
# Runs once, after the whole profile chain has been copied, so it catches the
# base rules and each profile's alike. Path-scoped rules and the user's
# project-conventions.md stay in .claude/rules/ (Claude-only by nature).
compose_agents_rules() {
  local f base
  [ -d .claude/rules ] || return 0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    base="${f##*/}"
    rule_is_path_scoped "$f" && continue
    [ "$base" = "project-conventions.md" ] && continue
    { echo; echo "<!-- from .claude/rules/$base -->"; cat "$f"; } >> "$AGENTS_TMP"
    rm -f "$f"
  done < <(find .claude/rules -maxdepth 1 -name '*.md' | sort)
}

# Write AGENTS.md (managed region) + the CLAUDE.md import shim.
finalize_agents_md() {
  local profile="$1"
  [ -f "$AGENTS_TMP" ] || return 0
  local body; body="$(cat "$AGENTS_TMP")"
  local managed
  managed="$(printf '%s\n# Agent instructions\n\nThis repository is configured from agentic-repo-template (profile: %s).\nEvery agent harness reads this file: Codex and OpenCode natively, Claude Code\nthrough the `@AGENTS.md` import in CLAUDE.md.\n%s\n%s\n' \
    "$AGENTS_BEGIN" "$profile" "$body" "$AGENTS_END")"

  printf '%s\n' "$managed" > .agents-managed.tmp
  if [ -f AGENTS.md ] && grep -qF "$AGENTS_BEGIN" AGENTS.md; then
    # Existing managed region: replace ONLY between the markers (D49 — never
    # clobber what the user wrote around it).
    awk -v b="$AGENTS_BEGIN" -v e="$AGENTS_END" -v f=".agents-managed.tmp" '
      index($0, b) { while ((getline line < f) > 0) print line; close(f); skip=1; next }
      index($0, e) { skip=0; next }
      !skip { print }
    ' AGENTS.md > AGENTS.md.new && mv AGENTS.md.new AGENTS.md
  elif [ -f AGENTS.md ]; then
    { cat .agents-managed.tmp; echo; cat AGENTS.md; } > AGENTS.md.new && mv AGENTS.md.new AGENTS.md
  else
    { cat .agents-managed.tmp; echo; \
      echo "<!-- Your own project instructions go below; the template never touches them. -->"; \
    } > AGENTS.md
  fi
  rm -f "$AGENTS_TMP" .agents-managed.tmp

  # CLAUDE.md: the import shim Anthropic documents, plus a pointer to the
  # Claude-only surfaces. Never overwrite a CLAUDE.md that already imports.
  if [ ! -f CLAUDE.md ] || ! grep -q '^@AGENTS.md' CLAUDE.md; then
    cat > CLAUDE.md <<'SHIM'
@AGENTS.md

## Claude Code specifics

The shared instructions live in `AGENTS.md` (imported above) so Codex and
OpenCode read the same bytes. Claude-only surfaces:

- `.claude/rules/*.md` — path-scoped rules; they load only when you touch
  matching files, which no other harness supports.
- `.claude/settings.json` — permissions, sandbox, hooks, plugin declaration.
- `.claude/skills/` — repo-local skills (also read by OpenCode).

Add Claude-specific instructions below this line; anything that should reach
every harness belongs in `AGENTS.md`.
SHIM
  fi
}

append_claude_md() {
  local profile_dir="$1"
  local snippet="$profile_dir/CLAUDE.append.md"
  [ -f "$snippet" ] || return 0
  { echo; cat "$snippet"; } >> .claude/CLAUDE.md
}

merge_skills_manifest() {
  local profile_dir="$1"
  local src="$profile_dir/skills.manifest.json"
  [ -f "$src" ] || return 0
  # An entry-less manifest is a no-op: do not materialize an empty
  # .claude/skills.manifest.json that refresh-skills.sh would then read as
  # "nothing to refresh" anyway. (v0.3: the paper tiers vendor no skills —
  # the agentic-paper plugin owns them all, M8.)
  local n
  n="$("$JQ" -r '(.skills // []) | length' "$src" 2>/dev/null || echo 0)"
  [ "$n" -gt 0 ] 2>/dev/null || return 0
  local dest=".claude/skills.manifest.json"
  [ -f "$dest" ] || echo '{"skills": []}' > "$dest"
  local tmp
  tmp=$(mktemp)
  "$JQ" -s '{ skills: (.[0].skills + .[1].skills) }' "$dest" "$src" > "$tmp"
  mv "$tmp" "$dest"
}

# --- plugin install + PROJECT-SCOPED verify (B1/B3) ---------------------------
# `claude plugin list --json` is MACHINE-GLOBAL and cwd-independent: on a box
# holding N template repos it returns every plugin every repo ever installed,
# plus every user-scope plugin. A naive "the plugin appears in the list" check
# goes green in repo #2..#N because repo #1 installed it. The predicate below
# filters realpath(projectPath)==realpath($PWD) AND .enabled, which is the only
# question that matters. macOS records the PHYSICAL path (/private/tmp/...)
# while $PWD is logical (/tmp/...), so BOTH sides are normalized; the compare is
# case-insensitive because APFS is case-insensitive by default.
plugin_norm_path() {
  local p="${1:-}"
  [ -n "$p" ] || return 0
  if [ -d "$p" ]; then ( cd "$p" 2>/dev/null && pwd -P ) && return 0; fi
  printf '%s' "$p"
}

# Echoes the sorted plugin ids enabled at PROJECT scope for $PWD; rc=2 if the
# listing is unusable (no claude / no jq / bad payload) — treat as NOT installed.
plugins_enabled_here() {
  local raw here lower_here n pp
  command -v claude >/dev/null 2>&1 || return 2
  command -v "$JQ" >/dev/null 2>&1 || return 2
  raw="$(claude plugin list --json 2>/dev/null)" || return 2
  printf '%s' "$raw" | "$JQ" -e 'type == "array"' >/dev/null 2>&1 || return 2
  here="$(pwd -P)"; lower_here="$(printf '%s' "$here" | tr '[:upper:]' '[:lower:]')"
  local matching=()
  while IFS= read -r pp; do
    [ -n "$pp" ] || continue
    n="$(plugin_norm_path "$pp")"
    [ "$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')" = "$lower_here" ] && matching+=("$pp")
  done < <(printf '%s' "$raw" | "$JQ" -r '[.[] | .projectPath // empty] | unique | .[]')
  [ "${#matching[@]}" -gt 0 ] || return 0
  printf '%s\n' "${matching[@]}" | "$JQ" -R . | "$JQ" -sr --argjson all "$raw" '
    . as $paths
    | [ $all[] | select(.projectPath != null)
        | select(.projectPath as $p | $paths | index($p))
        | select(.enabled == true) | .id ] | unique | .[]'
}

print_plugin_commands() {
  local declared="$1" prefix="${2:-  }"
  printf '%s%s\n' "$prefix" "claude plugin marketplace add ${MARKETPLACE_SOURCE} --scope project"
  printf '%s\n' "$declared" | sed "/^\$/d; s|^|${prefix}claude plugin install |; s|\$| --scope project|"
}

# Install + verify every capability plugin the merged settings declare.
# Contract: hard-fails LOUDLY (exit 5) naming the exact fix commands. A silent
# absence here is the U6 state — scaffold current, plugin missing, nothing errors
# at session start — which is precisely what this step exists to prevent.
ensure_plugins() {
  local declared d out rc missing="" enabled_here=""
  declared="$(plugins_declared_in .claude/settings.json | sed '/^$/d')"
  [ -n "$declared" ] || return 0

  echo
  echo "Capability plugins declared: $(printf '%s' "$declared" | tr '\n' ' ')"

  if [ "${ARP_SKIP_PLUGIN_INSTALL:-}" = "1" ]; then
    echo "warning: ARP_SKIP_PLUGIN_INSTALL=1 — the plugin step was SKIPPED." >&2
    echo "warning: the declaration in .claude/settings.json is a SILENT NO-OP on its own;" >&2
    echo "warning: the skills/agents it names are ABSENT until you run, IN THIS DIRECTORY:" >&2
    print_plugin_commands "$declared" "  " >&2
    return 0
  fi

  # 1. marketplace add — ALWAYS --scope project (B3). User scope would mutate
  #    ~/.claude/settings.json, which our own settings.json deny-lists.
  set +e
  out="$(claude plugin marketplace add "$MARKETPLACE_SOURCE" --scope project 2>&1)"; rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo >&2
    echo "error: marketplace registration FAILED (exit $rc):" >&2
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    echo "  The scaffold is complete. Finish the plugin step by hand, IN THIS DIRECTORY:" >&2
    print_plugin_commands "$declared" "    " >&2
    exit 5
  fi
  printf '%s\n' "$out" | sed 's/^/  /'

  # 2. install each declared plugin — ALWAYS --scope project
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    set +e
    out="$(claude plugin install "$d" --scope project 2>&1)"; rc=$?
    set -e
    printf '%s\n' "$out" | sed 's/^/  /'
  done <<EOF
$declared
EOF

  # 3. PROJECT-SCOPED verify (B1) — the authority, not the install exit codes.
  #    --allow-extra semantics: a user's own project-scope plugins are fine;
  #    only a DECLARED-but-absent plugin is a failure.
  set +e
  enabled_here="$(plugins_enabled_here)"; rc=$?
  set -e
  if [ "$rc" -eq 2 ]; then
    echo >&2
    echo "error: plugin verify COULD NOT RUN (no 'claude' or 'jq' on PATH, or the listing failed)." >&2
    echo "  Treat the plugins as NOT installed. Run IN THIS DIRECTORY:" >&2
    print_plugin_commands "$declared" "    " >&2
    exit 5
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$enabled_here" | grep -qxF "$d" || missing="${missing}${d}"$'\n'
  done <<EOF
$declared
EOF

  if [ -n "$missing" ]; then
    echo >&2
    echo "error: capability plugins NOT installed for THIS repo ($(pwd -P)):" >&2
    printf '%s' "$missing" | sed '/^$/d; s|^|    - |' >&2
    echo "  The scaffold is complete and nothing was lost — but the skills and agents" >&2
    echo "  these plugins carry are ABSENT, and Claude Code will not tell you so." >&2
    echo "  Run IN THIS DIRECTORY:" >&2
    print_plugin_commands "$missing" "    " >&2
    exit 5
  fi

  echo "  verified at project scope: $(printf '%s' "$enabled_here" | tr '\n' ' ')"
  # The installs rewrote settings.json in the CLI's own key order — re-canonicalize.
  canonicalize_settings
}

cleanup_template_metadata() {
  # Remove/reset root-level files that are template metadata, not user content.
  # These are present because GitHub's "Use this template" copies them from the
  # template repo's default branch; they document the template itself, not the
  # consuming project.

  # README.md: replace with a minimal stub carrying the repo name.
  # LICENSE, .gitignore, and the root CLAUDE.md stub are kept — all reasonable
  # starting points the user can keep or replace.
  if [ -f README.md ] && head -1 README.md | grep -q '^# agentic-repo-template'; then
    local repo_name
    repo_name=$(basename "$(pwd)")
    printf '# %s\n' "$repo_name" > README.md
  fi

  # CHANGELOG.md: template release history is not relevant to the consuming
  # project. Delete if it looks like our template CHANGELOG.
  if [ -f CHANGELOG.md ] && head -5 CHANGELOG.md | grep -q 'User-facing history of this template'; then
    rm -f CHANGELOG.md
  fi

  # bootstrap.sh: tooling for initializing OTHER directories from the template;
  # irrelevant inside an already-initialized consuming repo. Delete if it's ours.
  if [ -f bootstrap.sh ] && head -3 bootstrap.sh | grep -q 'initialize the CURRENT directory from agentic-repo-template'; then
    rm -f bootstrap.sh
  fi

  # upgrade.sh: same — you always fetch a fresh upgrade.sh (curl | bash) rather
  # than run a committed stale copy. Delete if it's ours.
  if [ -f upgrade.sh ] && head -3 upgrade.sh | grep -q 'upgrade an already-initialized repo to the latest template version'; then
    rm -f upgrade.sh
  fi

  # art.sh: the CLI itself — installed to ~/.local/bin, never checked into a
  # consuming repo. Delete if it's ours.
  for f in art.sh arp.sh; do
    if [ -f "$f" ] && head -4 "$f" | grep -q 'agentic-repo-template CLI'; then rm -f "$f"; fi
  done

  # fleet-upgrade.sh: operator tooling for mass upgrades across many repos;
  # not consumer content. Delete if it's ours.
  if [ -f fleet-upgrade.sh ] && head -4 fleet-upgrade.sh | grep -q 'template-initialized repo under one or more'; then
    rm -f fleet-upgrade.sh
  fi
}

stamp_template_version() {
  # Record which template version/profile was applied so /template-check can
  # compare against the latest GitHub release later.
  local applied_at profile="$1" cloud_compat_val="${2:-false}" strict_sandbox_val="${3:-0}"
  # Normalize strict_sandbox: caller may pass "0"/"1" (from arg-parse) or "true"/"false".
  case "$strict_sandbox_val" in
    1|true) strict_sandbox_val=true ;;
    *)      strict_sandbox_val=false ;;
  esac
  applied_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > .claude/.template-version <<EOF
version=${TEMPLATE_VERSION}
profile=${profile}
applied_at=${applied_at}
cloud_compat=${cloud_compat_val}
strict_sandbox=${strict_sandbox_val}
EOF
}

apply_cloud_compat() {
  # Make settings.json safe to load inside Claude Code on the web's nested
  # container. The web VM doesn't ship bubblewrap/socat and AppArmor on
  # Ubuntu 24.04 blocks unprivileged user namespaces, so an enabled sandbox
  # with failIfUnavailable=true aborts session startup. Patches applied:
  #   1. Remove sandbox.failIfUnavailable (defaults to false: warn + run
  #      commands unsandboxed when the OS sandbox can't initialize).
  #   2. Set sandbox.enableWeakerNestedSandbox=true so the Linux sandbox
  #      can run without privileged namespaces if a setup script does
  #      install bwrap+socat.
  #   3. Strip ~/.nix-profile, /nix, ~/.cache/devbox, ~/.local/share/devbox
  #      from sandbox.filesystem.allowWrite — these paths don't exist on
  #      the cloud VM and the bind-mount would fail if the sandbox ran.
  #   4. Remove context7@external-plugins from enabledPlugins (orphan: no
  #      "external-plugins" marketplace is declared anywhere in base).
  local settings=".claude/settings.json"
  [ -f "$settings" ] || { echo "error: $settings missing" >&2; exit 4; }
  local tmp; tmp=$(mktemp)
  "$JQ" '
    (if (.sandbox? != null)
      then .sandbox |= del(.failIfUnavailable)
      else .
      end)
    |
    (if (.sandbox? != null)
      then .sandbox.enableWeakerNestedSandbox = true
      else .
      end)
    |
    (if ((.sandbox.filesystem.allowWrite? // null) | type) == "array"
      then .sandbox.filesystem.allowWrite |= map(select(
        . != "/nix" and
        . != "~/.nix-profile" and
        . != "~/.cache/devbox" and
        . != "~/.local/share/devbox"
      ))
      else .
      end)
    |
    (if ((.enabledPlugins? // null) | type) == "object"
      then .enabledPlugins |= del(."context7@external-plugins")
      else .
      end)
  ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
}

apply_strict_sandbox() {
  # Opt-in hard-sandbox gate. Sets sandbox.failIfUnavailable = true so Claude
  # Code aborts session-start when the OS sandbox cannot initialize. Use for
  # managed deployments where sandboxing is a hard security requirement.
  local settings=".claude/settings.json"
  [ -f "$settings" ] || { echo "error: $settings missing" >&2; exit 4; }
  local tmp; tmp=$(mktemp)
  "$JQ" '
    (if (.sandbox? != null)
      then .sandbox.failIfUnavailable = true
      else .sandbox = { "failIfUnavailable": true }
      end)
  ' "$settings" > "$tmp"
  mv "$tmp" "$settings"
}

self_delete() {
  rm -rf .claude/profiles
  rm -f  .claude/init.sh
  rm -f  .claude/removed-entries.json  # upgrade-tooling manifest; read from the template source, not consumers
  rm -f  .claude/removed-files.txt     # same class: upgrade-tooling manifest
  rm -f  .claude/plugin-superseded-files.txt  # same class: upgrade-tooling manifest
}

main() {
  local profile=""
  local keep_profiles=0
  local dry_run=0
  local cloud_compat=0
  local strict_sandbox=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --keep-profiles)  keep_profiles=1; shift ;;
      --dry-run)        dry_run=1; shift ;;
      --strict-sandbox) strict_sandbox=1; shift ;;
      --cloud-compat)
        cloud_compat=1
        echo "warning: --cloud-compat is deprecated in v0.1.15+. Base settings are now cloud-safe by default; this flag is a no-op for failIfUnavailable removal. Still prunes devbox/nix paths from allowWrite (cosmetic)." >&2
        shift ;;
      -h|--help)        usage; exit 0 ;;
      -*)               echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
      *)
        if [ -z "$profile" ]; then
          profile="$1"; shift
        else
          echo "unexpected argument: $1" >&2; usage >&2; exit 2
        fi
        ;;
    esac
  done

  # Patch-only mode: --cloud-compat alone, applied to an already-initialized
  # repo (profiles/ is typically gone — init.sh self-deleted after the
  # original profile apply). Skip the profile chain entirely.
  if [ -z "$profile" ] && [ "$cloud_compat" = "1" ]; then
    if [ ! -f .claude/settings.json ]; then
      echo "error: .claude/settings.json missing. Nothing to patch." >&2
      exit 4
    fi
    if ! command -v "$JQ" >/dev/null 2>&1; then
      echo "error: jq not found on PATH (looked for '$JQ'). Install jq and re-run." >&2
      exit 3
    fi
    if [ "$dry_run" = "1" ]; then
      echo "[dry-run] would apply cloud-compat patches to .claude/settings.json:"
      echo "[dry-run]   - remove sandbox.failIfUnavailable"
      echo "[dry-run]   - set sandbox.enableWeakerNestedSandbox = true"
      echo "[dry-run]   - prune devbox/nix paths from sandbox.filesystem.allowWrite"
      echo "[dry-run]   - remove context7@external-plugins from enabledPlugins"
      exit 0
    fi
    apply_cloud_compat
    canonicalize_settings
    # Preserve any existing profile= line; only update/add cloud_compat=.
    if [ -f .claude/.template-version ] && grep -q '^cloud_compat=' .claude/.template-version; then
      tmp=$(mktemp)
      sed 's/^cloud_compat=.*/cloud_compat=true/' .claude/.template-version > "$tmp"
      mv "$tmp" .claude/.template-version
    elif [ -f .claude/.template-version ]; then
      echo "cloud_compat=true" >> .claude/.template-version
    else
      cat > .claude/.template-version <<EOF
version=${TEMPLATE_VERSION}
profile=unknown
applied_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cloud_compat=true
strict_sandbox=false
EOF
    fi
    echo
    echo "Cloud-compat patches applied to existing .claude/settings.json:"
    echo "  - sandbox.failIfUnavailable removed (defaults to false: warn + run unsandboxed)"
    echo "  - sandbox.enableWeakerNestedSandbox = true"
    echo "  - devbox / nix paths pruned from sandbox.filesystem.allowWrite"
    echo "  - context7@external-plugins removed from enabledPlugins"
    exit 0
  fi

  if [ -z "$profile" ]; then
    echo "error: profile argument required" >&2
    usage >&2
    exit 2
  fi

  if ! is_valid_profile "$profile"; then
    echo "unknown profile: $profile" >&2
    usage >&2
    exit 2
  fi

  local chain
  chain=$(resolve_chain "$profile")

  # Debug hook for testing chain resolution.
  if [ "${DEBUG_PRINT_CHAIN:-0}" = "1" ]; then
    echo "$chain"
    exit 0
  fi

  preflight

  # Does this chain declare a capability plugin? If so, the payload that plugin
  # ships is NOT file-copied (a stale scaffold copy silently beats the plugin).
  local declared_chain skip_superseded=0
  declared_chain="$(declared_plugins_for_chain "$chain" | sed '/^$/d')"
  [ -n "$declared_chain" ] && skip_superseded=1

  for p in $chain; do
    profile_dir=".claude/profiles/$p"
    [ -d "$profile_dir" ] || { echo "profile dir missing: $profile_dir" >&2; exit 4; }

    if [ "$dry_run" = "1" ]; then
      echo "[dry-run] would merge $profile_dir/settings.overlay.json"
      echo "[dry-run] would copy $profile_dir/rules/ and $profile_dir/skills/"
      [ "$skip_superseded" = "1" ] && echo "[dry-run]   (skipping the paths the capability plugin ships)"
      echo "[dry-run] would append $profile_dir/CLAUDE.append.md"
      [ -f "$profile_dir/skills.manifest.json" ] \
        && echo "[dry-run] would merge $profile_dir/skills.manifest.json"
      continue
    fi

    apply_settings_overlay "$profile_dir"
    copy_rules_and_skills "$profile_dir" "$skip_superseded"
    append_claude_md "$profile_dir"
    merge_skills_manifest "$profile_dir"
  done

  if [ "$dry_run" != "1" ]; then compose_agents_rules; finalize_agents_md "$profile"; fi

  if [ "$dry_run" = "1" ] && [ -n "$declared_chain" ]; then
    echo "[dry-run] would then run, IN THIS DIRECTORY:"
    print_plugin_commands "$declared_chain" "[dry-run]   "
    echo "[dry-run]   + a project-scoped verify (realpath(projectPath)==\$PWD && .enabled)"
    echo "[dry-run]   + jq -S canonicalization of .claude/settings.json"
  fi

  if [ "$dry_run" = "1" ] && [ "$cloud_compat" = "1" ]; then
    echo "[dry-run] would apply cloud-compat patches to .claude/settings.json after profile merge"
  fi
  if [ "$dry_run" = "1" ] && [ "$strict_sandbox" = "1" ]; then
    echo "[dry-run] would apply --strict-sandbox patch (set sandbox.failIfUnavailable = true)"
  fi

  if [ "$dry_run" = "0" ] && [ "$cloud_compat" = "1" ]; then
    apply_cloud_compat
  fi
  if [ "$dry_run" = "0" ] && [ "$strict_sandbox" = "1" ]; then
    apply_strict_sandbox
  fi

  # Author settings.json in `jq -S` order so the first `claude plugin install`
  # rewrite is a no-op diff instead of an eleven-key reshuffle (Phase-0 carry-2).
  if [ "$dry_run" = "0" ]; then
    canonicalize_settings
  fi

  if [ "$dry_run" = "0" ]; then
    cleanup_template_metadata
    if [ "$cloud_compat" = "1" ]; then
      stamp_template_version "$profile" true "$strict_sandbox"
    else
      stamp_template_version "$profile" false "$strict_sandbox"
    fi
  fi

  if [ "$dry_run" = "0" ] && [ "$keep_profiles" = "0" ]; then
    self_delete
  fi

  if [ "$dry_run" = "0" ]; then
    local cc_suffix=""
    [ "$cloud_compat" = "1" ] && cc_suffix="$cc_suffix (cloud-compat applied, deprecated)"
    [ "$strict_sandbox" = "1" ] && cc_suffix="$cc_suffix (strict-sandbox gate enabled)"
    echo
    echo "Profile \"$profile\" applied${cc_suffix}."
    echo "  Chain: $chain"
    echo "  Plugins enabled: $("$JQ" -r '.enabledPlugins | length' .claude/settings.json)"
    echo "  Rules present:   $(find .claude/rules -name '*.md' -type f | wc -l | tr -d ' ')"
    if [ -d .claude/skills ]; then
      echo "  Skills vendored: $(find .claude/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')"
    fi
    if [ -d .claude/agents ]; then
      echo "  Agents present:  $(find .claude/agents -maxdepth 1 -mindepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
    fi
    if [ -d .claude/hooks ]; then
      echo "  Hook scripts:    $(find .claude/hooks -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')"
    fi
    if [ -d .claude/templates ]; then
      echo "  Templates:       $(find .claude/templates -maxdepth 1 -mindepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"
    fi
    if [ -n "$declared_chain" ]; then
      echo "  Capability plugins: $(printf '%s' "$declared_chain" | tr '\n' ' ') (installed below, NOT file-copied)"
    fi
    if [ "$keep_profiles" = "1" ]; then
      echo "  profiles/ and init.sh retained (--keep-profiles)."
    else
      echo "  profiles/ and init.sh removed (self-cleaned)."
    fi
  fi

  # LAST: the scaffold above is complete and reported before the plugin step can
  # fail, so a plugin failure never hides the scaffold outcome. ensure_plugins
  # exits 5 on failure, naming the exact commands to run by hand.
  if [ "$dry_run" = "0" ]; then
    ensure_plugins
  fi
}

main "$@"
