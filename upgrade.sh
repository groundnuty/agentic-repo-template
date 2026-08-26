#!/usr/bin/env bash
#
# upgrade.sh — upgrade an already-initialized repo to the latest template version.
#
# Reads .claude/.template-version to learn the repo's profile and sandbox flags,
# so you don't have to remember them. One command, no arguments:
#
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh | bash
#
# It backs up the existing .claude/ to .claude.pre-upgrade-<oldversion>/, then
# OVERLAYS the template-owned files in place (v0.2.8+):
#   - template files (settings.json, rules, skills, agents, hooks, templates,
#     commands) are updated; files the template deliberately removed are deleted
#     (manifest: removed-files.txt); root-level .example files are regenerated
#   - .claude/CLAUDE.md and rules/project-conventions.md are NEVER overwritten —
#     the fresh template CLAUDE.md lands in the backup as CLAUDE.md.template-new
#     for manual merge
#   - EVERYTHING ELSE in .claude/ — custom rules, scripts/, hooks, .macf/, any
#     file you added — is NOT TOUCHED. (v0.2.0–v0.2.7 upgrades violated this and
#     destroyed custom files; recover them from .claude.pre-upgrade-*/.)
# The stamp is bumped to the new version.
#
# v0.3+ also installs and verifies the profile's CAPABILITY PLUGINS at project
# scope, and — only once that verify is green — deletes the file copies the
# plugin now supersedes (manifest: plugin-superseded-files.txt). The plugin step
# can never abort the scaffold upgrade; it reports and exits 4 at the very end.
#
# The settings report distinguishes entries the NEW TEMPLATE REMOVED (do not
# restore them) from YOUR CUSTOMIZATIONS (move to settings.local.json).
#
# Options:
#   --ref <tag>   Upgrade to a specific version instead of latest (default: main).
#   --dry-run     Show what would change without modifying anything.
#   -h, --help    Show this help.
#
# Environment:
#   ARP_SKIP_PLUGIN_INSTALL=1  Do not run `claude plugin ...`; print the exact
#                              commands and a warning instead (tests, offline).
#
# Exit codes: 0 ok · 1 no stamp / unusable stamp · 2 usage · 3 source unreachable
#             4 the SCAFFOLD upgrade succeeded but the PLUGIN step did not.

set -euo pipefail

REPO="groundnuty/agentic-repo-template"
# ARP_UPGRADE_SOURCE: local dir (with .claude/) or git URL. Default = public repo.
SOURCE="${ARP_UPGRADE_SOURCE:-https://github.com/${REPO}.git}"
REF="main"
DRY_RUN=0

# Root-level template-owned files (regenerated on upgrade). Live user files
# (.mcp.json without .example) are never listed here and never touched.
ROOT_FILES=".mcp.json.example k8s-mcp.toml.example"

# --- capability plugins (v0.3) ------------------------------------------------
# Which plugins a profile declares is DATA, read from the settings the fresh
# template generates — never a hardcoded profile list here. Only ids from OUR
# marketplace are ours to install; @claude-plugins-official entries are Claude
# Code's own. ARP_MARKETPLACE_SOURCE lets tests point at a local marketplace.
MARKETPLACE_NAME="${ARP_MARKETPLACE_NAME:-agentic-plugins}"
MARKETPLACE_SOURCE="${ARP_MARKETPLACE_SOURCE:-groundnuty/agentic-plugins}"
PLUGIN_RC=0          # 0 = ok/not-applicable, 1 = the step failed (never aborts)
PLUGIN_DIAG=""       # human-readable failure text, printed AFTER the report
BACKUP=""            # set once the pre-upgrade backup exists

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)   REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "upgrade: unknown option '$1'" >&2; usage >&2; exit 2 ;;
  esac
done

STAMP=".claude/.template-version"
if [ ! -f "$STAMP" ]; then
  echo "upgrade: no $STAMP in $(pwd)." >&2
  echo "         This repo wasn't initialized from the template, or predates v0.1.9 (no stamp)." >&2
  echo "         For a fresh init use bootstrap.sh; to start tracking, create the stamp by hand" >&2
  echo "         (run /template-check for the exact snippet)." >&2
  exit 1
fi

# Tolerate missing keys: stamps older than v0.1.14/15 lack cloud_compat/strict_sandbox,
# and under pipefail a failed grep would kill the script before any output.
stamp_get() { { grep "^$1=" "$STAMP" || true; } | head -1 | cut -d= -f2-; }
PROFILE="$(stamp_get profile)"
OLD_VERSION="$(stamp_get version)"
CLOUD_COMPAT="$(stamp_get cloud_compat)"
STRICT_SANDBOX="$(stamp_get strict_sandbox)"

if [ -z "$PROFILE" ] || [ "$PROFILE" = "unknown" ]; then
  echo "upgrade: stamp has no usable 'profile=' line; can't determine how to re-init." >&2
  echo "         Edit $STAMP to set profile=<info|research|paper|paper-latex|code> and retry." >&2
  exit 1
fi

# Resolve source tree (local dir = no clone; else shallow clone at REF).
SCRATCH=""; WORK=""
cleanup() { rm -rf ${SCRATCH:+"$SCRATCH"} ${WORK:+"$WORK"} 2>/dev/null; return 0; }
trap cleanup EXIT

if [ -d "$SOURCE" ] && [ -d "$SOURCE/.claude" ]; then
  SRC="$SOURCE"
else
  command -v git >/dev/null 2>&1 || { echo "upgrade: git not found on PATH." >&2; exit 3; }
  SCRATCH="$(mktemp -d)"
  if ! git clone --depth=1 --branch "$REF" "$SOURCE" "$SCRATCH" >/dev/null 2>&1; then
    echo "upgrade: failed to clone $SOURCE at ref '$REF'." >&2
    exit 3
  fi
  SRC="$SCRATCH"
fi
[ -f "$SRC/.claude/init.sh" ] || { echo "upgrade: source has no .claude/init.sh ($SRC)." >&2; exit 3; }

NEW_VERSION="$(grep 'TEMPLATE_VERSION=' "$SRC/.claude/init.sh" | head -1 | sed 's/.*"\(.*\)".*/\1/')"

echo "Current: ${OLD_VERSION:-unknown} (profile: $PROFILE${CLOUD_COMPAT:+, cloud_compat=$CLOUD_COMPAT}${STRICT_SANDBOX:+, strict_sandbox=$STRICT_SANDBOX})"
echo "Latest:  ${NEW_VERSION:-unknown}"

# --- capability plugin step (v0.3) --------------------------------------------
# Defined HERE, above the version compare, so the "already up to date" fast path
# below can call it without building $WORK.
#
# The B1 predicate, inlined: upgrade.sh is a single `curl | bash` file and cannot
# source anything. `claude plugin list --json` is MACHINE-GLOBAL — it returns
# every plugin every repo on this box ever installed, plus user-scope ones — so
# filtering realpath(projectPath)==realpath($PWD) AND .enabled is the only way to
# answer "is it installed FOR THIS REPO". macOS records the PHYSICAL path
# (/private/tmp/x) while $PWD is logical (/tmp/x): both sides are normalized.
plugin_norm_path() {
  local p="${1:-}"
  [ -n "$p" ] || return 0
  if [ -d "$p" ]; then ( cd "$p" 2>/dev/null && pwd -P ) && return 0; fi
  printf '%s' "$p"
}

# echoes the sorted ids enabled at PROJECT scope for $PWD; rc=2 if unusable
plugins_enabled_here() {
  local raw here lower_here n pp
  command -v claude >/dev/null 2>&1 || return 2
  command -v jq >/dev/null 2>&1 || return 2
  raw="$(claude plugin list --json 2>/dev/null)" || return 2
  printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1 || return 2
  here="$(pwd -P)"; lower_here="$(printf '%s' "$here" | tr '[:upper:]' '[:lower:]')"
  local matching=()
  while IFS= read -r pp; do
    [ -n "$pp" ] || continue
    n="$(plugin_norm_path "$pp")"
    [ "$(printf '%s' "$n" | tr '[:upper:]' '[:lower:]')" = "$lower_here" ] && matching+=("$pp")
  done < <(printf '%s' "$raw" | jq -r '[.[] | .projectPath // empty] | unique | .[]')
  [ "${#matching[@]}" -gt 0 ] || return 0
  printf '%s\n' "${matching[@]}" | jq -R . | jq -sr --argjson all "$raw" '
    . as $paths
    | [ $all[] | select(.projectPath != null)
        | select(.projectPath as $p | $paths | index($p))
        | select(.enabled == true) | .id ] | unique | .[]'
}

# The declared set is DATA, read from settings — never a hardcoded profile list.
plugins_declared_in() {
  local file="$1"
  [ -f "$file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r --arg mkt "@$MARKETPLACE_NAME" \
    '(.enabledPlugins // {}) | keys[] | select(endswith($mkt))' "$file" 2>/dev/null || true
}

plugin_commands_for() {
  local declared="$1" prefix="${2:-    }"
  printf '%s%s\n' "$prefix" "claude plugin marketplace add ${MARKETPLACE_SOURCE} --scope project"
  printf '%s\n' "$declared" | sed "/^\$/d; s|^|${prefix}claude plugin install |; s|\$| --scope project|"
}

# Apply one removal manifest. Lines ending in "/" are directories (rm -rf).
# $2 is a directory to stash removals into first, or "" when the caller already
# holds a full pre-upgrade backup of .claude/.
apply_removal_manifest() {
  local manifest="$1" stash="${2:-}" rf target removed=""
  [ -f "$manifest" ] || return 0
  # `|| [ -n "$rf" ]` so a manifest without a trailing newline keeps its last entry.
  while IFS= read -r rf || [ -n "$rf" ]; do
    case "$rf" in ""|\#*) continue ;; esac
    rf="${rf%/}"
    target=".claude/$rf"
    [ -e "$target" ] || continue
    if [ -n "$stash" ]; then
      mkdir -p "$stash/$(dirname "$rf")" 2>/dev/null || true
      cp -R "$target" "$stash/$rf" 2>/dev/null || true
    fi
    rm -rf "$target" 2>/dev/null || true
    removed="${removed}${rf}"$'\n'
  done < "$manifest"
  printf '%s' "$removed"
}

# Drop plugin-owned entries from the consumer's skills.manifest.json (M8): left
# behind, `refresh-skills.sh` would re-clone humanizer into .claude/skills/ and
# the stale copy would silently beat the plugin again. User-added entries are
# preserved; the file is deleted only when nothing is left.
prune_plugin_skills_manifest() {
  local manifest="$1" dest=".claude/skills.manifest.json" names drop tmp
  [ -f "$dest" ] && [ -f "$manifest" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  # Plugin-owned skill names are exactly the manifest's "skills/<name>/" lines.
  names="$(sed 's/#.*//' "$manifest" | sed -n 's|^skills/\([^/]*\)/[[:space:]]*$|\1|p')"
  [ -n "$names" ] || return 0
  drop="$(printf '%s\n' "$names" | jq -Rs 'split("\n") | map(select(length > 0))')"
  tmp="$(mktemp)"
  if jq --argjson drop "$drop" \
       '{ skills: ((.skills // []) | map(select(.name as $n | ($drop | index($n)) | not))) }' \
       "$dest" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    if [ "$(jq -r '.skills | length' "$tmp")" = "0" ]; then
      rm -f "$dest"
      echo "  skills.manifest.json removed (every entry is now plugin-owned)"
    elif ! diff -q "$tmp" "$dest" >/dev/null 2>&1; then
      cp "$tmp" "$dest"
      echo "  skills.manifest.json pruned of plugin-owned entries"
    fi
  fi
  rm -f "$tmp" 2>/dev/null || true
}

# Delete the file copies the plugin supersedes. Called ONLY from the verified
# branch: a repo whose install failed keeps its copies and keeps working.
dedupe_plugin_superseded() {
  local manifest="$SRC/.claude/plugin-superseded-files.txt" stash="" removed d n
  [ -f "$manifest" ] || return 0
  # On the main path the pre-upgrade backup already holds every one of these
  # paths. On the fast path there is no backup for this run, so stash first —
  # a consumer may have HAND-EDITED a shipped skill (the D49 lesson).
  if [ -z "$BACKUP" ]; then
    stash=".claude.pre-upgrade-${OLD_VERSION:-unknown}-plugin-dedupe"
    if [ -e "$stash" ]; then
      n=1; while [ -e "${stash}.${n}" ]; do n=$((n+1)); done; stash="${stash}.${n}"
    fi
  fi
  removed="$(apply_removal_manifest "$manifest" "$stash")"
  if [ -n "$removed" ]; then
    echo "  superseded file copies removed (the plugin ships these now):"
    printf '%s\n' "$removed" | sed '/^$/d; s|^|    - .claude/|'
    if [ -n "$stash" ]; then
      echo "    copies kept in $stash/"
    else
      echo "    copies kept in $BACKUP/"
    fi
    # Directories emptied by the removals (e.g. agents/ on a paper repo) go too.
    for d in .claude/agents .claude/skills .claude/templates .claude/rules; do
      [ -d "$d" ] && rmdir "$d" 2>/dev/null
    done
  elif [ -n "$stash" ] && [ -d "$stash" ]; then
    rmdir "$stash" 2>/dev/null || true
  fi
  prune_plugin_skills_manifest "$manifest"
  return 0
}

# Install + project-scoped verify the profile's declared capability plugins.
#
# WHERE THIS SITS AND WHY (B2', re-derived against the v0.2.8 OVERLAY model):
#   * The step must run AFTER the overlay: `claude plugin install --scope project`
#     writes .claude/settings.json and the overlay would clobber those writes; it
#     also needs the NEW settings.json (with extraKnownMarketplaces) on disk so
#     the CLI's writes land on the new shape.
#   * It therefore runs after the overlay, under a function-scoped `set +e`, and
#     its failure is REPORTED, not thrown. The scaffold is left fully-new either
#     way; the exit code and the diagnostic carry the bad news.
#   * FAILING HERE IS THE U6 SILENT-ABSENCE STATE (scaffold says v0.3.0, plugin
#     absent, nothing errors at session start). It MUST be loud.
#
# CONTRACT: never aborts. `set +e` is scoped here; failure sets PLUGIN_RC=1.
ensure_plugins() {
  local declared d out rc missing="" enabled_here=""
  if ! command -v jq >/dev/null 2>&1; then
    echo
    echo "warning: jq is not on PATH, so the capability-plugin declaration could not be read."
    echo "         If this repo's profile declares a plugin, it was NOT installed or verified."
    return 0
  fi
  declared="$(plugins_declared_in .claude/settings.json | sed '/^$/d')"
  [ -n "$declared" ] || return 0

  set +e   # scoped: nothing below may kill the script
  echo
  echo "Capability plugins for profile '$PROFILE': $(printf '%s' "$declared" | tr '\n' ' ')"

  if [ "${ARP_SKIP_PLUGIN_INSTALL:-}" = "1" ]; then
    echo "  ARP_SKIP_PLUGIN_INSTALL=1 — SKIPPED. The committed declaration is a silent"
    echo "  no-op on its own; run these IN THIS DIRECTORY to actually get the plugin:"
    plugin_commands_for "$declared" "    "
    set -e; return 0
  fi

  # 1. marketplace add — ALWAYS --scope project (B3). User scope would mutate
  #    ~/.claude/settings.json, which our own settings.json deny-lists.
  out="$(claude plugin marketplace add "$MARKETPLACE_SOURCE" --scope project 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then
    PLUGIN_RC=1
    PLUGIN_DIAG="$(printf '%s\n' \
      "  marketplace registration FAILED (exit $rc):" \
      "$(printf '%s\n' "$out" | sed 's/^/    /')" \
      "  Fix — run IN THIS DIRECTORY:" \
      "$(plugin_commands_for "$declared" "    ")")"
    set -e; return 0
  fi
  printf '%s\n' "$out" | sed 's/^/  /'

  # 2. install each declared plugin — ALWAYS --scope project
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    out="$(claude plugin install "$d" --scope project 2>&1)"; rc=$?
    printf '%s\n' "$out" | sed 's/^/  /'
  done <<EOF
$declared
EOF

  # 3. PROJECT-SCOPED verify (B1) — the authority, not the install exit codes.
  #    --allow-extra semantics: the user's own project-scope plugins are fine.
  enabled_here="$(plugins_enabled_here)"; rc=$?
  if [ "$rc" -eq 2 ]; then
    PLUGIN_RC=1
    PLUGIN_DIAG="  plugin verify COULD NOT RUN (no 'claude' or 'jq' on PATH, or the listing failed).
  Treat the plugins as NOT installed. Run IN THIS DIRECTORY:
$(plugin_commands_for "$declared" "    ")"
    set -e; return 0
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$enabled_here" | grep -qxF "$d" || missing="${missing}${d}"$'\n'
  done <<EOF
$declared
EOF

  if [ -n "$missing" ]; then
    PLUGIN_RC=1
    PLUGIN_DIAG="  NOT installed for THIS repo ($(pwd -P)):
$(printf '%s' "$missing" | sed '/^$/d; s|^|    - |')
  The scaffold upgraded fine and NOTHING was lost — but the skills and agents
  these plugins carry are ABSENT, and Claude Code will not tell you so (it
  reports declared-but-absent plugins as installed). Run IN THIS DIRECTORY:
$(plugin_commands_for "$missing" "    ")
  Then re-run: bash upgrade.sh   (it re-verifies even when already up to date)"
  else
    echo "  verified at project scope: $(printf '%s' "$enabled_here" | tr '\n' ' ')"
    # ONLY NOW is deduping safe: the capability is provably present.
    dedupe_plugin_superseded
    # 4. canonicalize — the CLI rewrites settings.json in an unstable key order
    #    (measured: 3 different orders, 162 churn lines for one semantic
    #    addition). jq -S is idempotent; init.sh authors in the same order.
    if command -v jq >/dev/null 2>&1 && [ -f .claude/settings.json ]; then
      tmp="$(mktemp)" && jq -S . .claude/settings.json > "$tmp" 2>/dev/null \
        && [ -s "$tmp" ] && mv "$tmp" .claude/settings.json
      rm -f "$tmp" 2>/dev/null || true
    fi
  fi
  set -e
  return 0
}

# WAS: `echo "Already up to date. Nothing to do."; exit 0`. That early exit is a
# TRAP once a plugin step exists: an upgrade whose overlay succeeded but whose
# plugin install failed bumps the stamp anyway (the stamp is a template-owned
# file the overlay copies), so the follow-up run would print "Already up to
# date", exit 0, and bury the missing plugins forever. Verify, then exit.
if [ -n "$OLD_VERSION" ] && [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
  echo "Already up to date (scaffold)."
  if [ "$DRY_RUN" -eq 1 ]; then
    _dp="$(plugins_declared_in .claude/settings.json | sed '/^$/d')"
    if [ -n "$_dp" ]; then
      echo "[dry-run] would verify capability plugins at project scope by running:"
      plugin_commands_for "$_dp" "[dry-run]   "
      echo "[dry-run]   + a project-scoped verify (realpath(projectPath)==\$PWD && .enabled)"
    else
      echo "[dry-run] profile '$PROFILE' declares no capability plugins."
    fi
    exit 0
  fi
  ensure_plugins
  if [ "$PLUGIN_RC" -ne 0 ]; then
    echo
    echo "PLUGIN STEP FAILED — the scaffold is current, the plugins are NOT."
    printf '%s\n' "$PLUGIN_DIAG"
    exit 4
  fi
  echo "Nothing to do."
  exit 0
fi

# CHANGELOG delta (best effort): version headers newer than OLD_VERSION.
if [ -f "$SRC/CHANGELOG.md" ] && [ -n "$OLD_VERSION" ]; then
  delta="$(awk -v oldhdr="## [$OLD_VERSION]" '
    /^## \[v/ { if (index($0, oldhdr)) exit; sub(/^## /, ""); print "  " $0 }
  ' "$SRC/CHANGELOG.md" 2>/dev/null || true)"
  if [ -n "$delta" ]; then
    echo
    echo "Changes ${OLD_VERSION} -> ${NEW_VERSION}:"
    echo "$delta"
  fi
fi

# Generate the fresh template-owned tree by re-running init with the stamped
# profile + flags. init.sh also places root-level files (e.g. .mcp.json.example)
# into $WORK's root.
WORK="$(mktemp -d)"
cp -R "$SRC/.claude" "$WORK/"
FLAGS=()
[ "$CLOUD_COMPAT" = "true" ] && FLAGS+=(--cloud-compat)
[ "$STRICT_SANDBOX" = "true" ] && FLAGS+=(--strict-sandbox)
# ARP_SKIP_PLUGIN_INSTALL=1 is MANDATORY here: this init runs in a throwaway
# temp dir purely to generate the template-owned tree. Letting it run
# `claude plugin install --scope project` would install the plugin FOR THE TEMP
# DIRECTORY — machine state pointing at a path that is deleted seconds later,
# and no install for the repo being upgraded. The real install happens below,
# in the repo, via ensure_plugins.
if ! (cd "$WORK" && ARP_SKIP_PLUGIN_INSTALL=1 bash ./.claude/init.sh "$PROFILE" ${FLAGS[@]+"${FLAGS[@]}"} > "$WORK/init.log" 2>&1); then
  echo "upgrade: the new template's init.sh failed while generating the fresh tree." >&2
  echo "         NOTHING was changed in this repo. Output:" >&2
  sed 's/^/    /' "$WORK/init.log" >&2
  exit 3
fi

# --- Settings report ---------------------------------------------------------
# Diff the existing settings.json against the freshly generated one, then
# PARTITION the differences using the template's removed-entries manifest
# ($SRC/.claude/removed-entries.json): entries the template removed on purpose
# are labeled DO-NOT-RESTORE; everything else is a genuine user customization.
report_custom_settings() {
  local old=".claude/settings.json" new="$WORK/.claude/settings.json"
  local manifest="$SRC/.claude/removed-entries.json" any=0
  [ -f "$old" ] && [ -f "$new" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local p
  for p in ".permissions.allow" ".permissions.deny" ".permissions.ask" ".sandbox.excludedCommands"; do
    local d removed="" custom=""
    d="$(jq -rn --slurpfile o "$old" --slurpfile n "$new" \
      "((\$o[0]|$p//[]) - (\$n[0]|$p//[]))[]" 2>/dev/null || true)"
    [ -n "$d" ] || continue
    if [ -f "$manifest" ]; then
      removed="$(printf '%s\n' "$d" | jq -rRn --slurpfile m "$manifest" --arg p "$p" \
        '[inputs] as $in | ($m[0][$p] // []) as $rm | $in[] | select(. as $x | $rm | index($x))' 2>/dev/null || true)"
      custom="$(printf '%s\n' "$d" | jq -rRn --slurpfile m "$manifest" --arg p "$p" \
        '[inputs] as $in | ($m[0][$p] // []) as $rm | $in[] | select(. as $x | $rm | index($x) | not)' 2>/dev/null || true)"
    else
      custom="$d"
    fi
    [ "$any" -eq 0 ] && { echo; echo "settings.json differences vs the new template:"; any=1; }
    if [ -n "$removed" ]; then
      echo "  $p — REMOVED BY THE NEW TEMPLATE (do NOT restore; see CHANGELOG):"
      printf '%s\n' "$removed" | sed 's/^/    - /'
    fi
    if [ -n "$custom" ]; then
      echo "  $p — your customizations (move to .claude/settings.local.json):"
      printf '%s\n' "$custom" | sed 's/^/    - /'
    fi
  done
  # Keys the old config has that the new one doesn't: plugins, marketplaces,
  # env vars, hook events, and top-level scalars.
  local sec
  for sec in enabledPlugins marketplaces extraKnownMarketplaces env hooks; do
    local dk
    dk="$(jq -rn --slurpfile o "$old" --slurpfile n "$new" \
      "((\$o[0].$sec//{})|keys) - ((\$n[0].$sec//{})|keys) | .[]" 2>/dev/null || true)"
    [ -n "$dk" ] || continue
    [ "$any" -eq 0 ] && { echo; echo "settings.json differences vs the new template:"; any=1; }
    local removed="" custom="$dk" manifest="$SRC/.claude/removed-entries.json"
    if [ -f "$manifest" ]; then
      removed="$(printf '%s\n' "$dk" | jq -rRn --slurpfile m "$manifest" --arg p ".$sec" \
        '[inputs] as $in | ($m[0][$p] // []) as $rm | $in[] | select(. as $x | $rm | index($x))' 2>/dev/null || true)"
      custom="$(printf '%s\n' "$dk" | jq -rRn --slurpfile m "$manifest" --arg p ".$sec" \
        '[inputs] as $in | ($m[0][$p] // []) as $rm | $in[] | select(. as $x | $rm | index($x) | not)' 2>/dev/null || true)"
    fi
    if [ -n "$removed" ]; then
      echo "  .$sec — REMOVED BY THE NEW TEMPLATE (do NOT restore; see CHANGELOG):"
      printf '%s\n' "$removed" | sed 's/^/    - /'
    fi
    if [ -n "$custom" ]; then
      echo "  .$sec keys — your customizations (re-apply via .claude/settings.local.json):"
      printf '%s\n' "$custom" | sed 's/^/    - /'
      # settings.json is template-owned, so a consumer's own hook registration is
      # replaced by the upgrade. Naming the key is not enough: an AGENT cannot put
      # it back (settings.json is deny-listed, and widening its own permissions is
      # forbidden), so only a human can — print the exact JSON to paste back.
      if [ "$sec" = "hooks" ]; then
        local block
        block="$(printf '%s\n' "$custom" | jq -Rn --slurpfile o "$old" \
          '[inputs] as $k | {hooks: ($o[0].hooks | with_entries(select(.key as $x | $k | index($x))))}' 2>/dev/null || true)"
        if [ -n "$block" ]; then
          echo
          echo "  ** HOOK REGISTRATION REMOVED — the hook SCRIPTS survive, their wiring does not."
          echo "     If any of these is a security guard, it is OFF until you paste this back into"
          echo "     .claude/settings.local.json (an agent cannot do it for you):"
          printf '%s\n' "$block" | sed 's/^/     /'
          echo
        fi
      fi
    fi
  done
  local scal
  scal="$(jq -rn --slurpfile o "$old" --slurpfile n "$new" \
    '($o[0]|with_entries(select(.value|type!="object" and type!="array"))|keys) - ($n[0]|with_entries(select(.value|type!="object" and type!="array"))|keys) | .[]' 2>/dev/null || true)"
  if [ -n "$scal" ]; then
    [ "$any" -eq 0 ] && { echo; echo "settings.json differences vs the new template:"; any=1; }
    echo "  top-level keys only in your current config:"
    printf '%s\n' "$scal" | sed 's/^/    - /'
  fi
  return 0
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "[dry-run] would back up .claude/ -> .claude.pre-upgrade-${OLD_VERSION:-unknown}/"
  echo "[dry-run] would overlay template-owned files in place (CLAUDE.md + rules/project-conventions.md never overwritten;\n[dry-run] custom files untouched); apply removed-files.txt deletions; regenerate root files: $ROOT_FILES"
  echo "[dry-run] would preserve:   settings.local.json, rules/project-conventions.md, audit.log, session-reports/"
  _dp="$(plugins_declared_in "$WORK/.claude/settings.json" | sed '/^$/d')"
  if [ -n "$_dp" ]; then
    echo "[dry-run] would then run, IN THIS DIRECTORY, after the overlay:"
    plugin_commands_for "$_dp" "[dry-run]   "
    echo "[dry-run]   + a project-scoped verify (realpath(projectPath)==\$PWD && .enabled)"
    echo "[dry-run]   + jq -S canonicalization of .claude/settings.json"
    if [ -f "$SRC/.claude/plugin-superseded-files.txt" ]; then
      echo "[dry-run]   + ONLY IF that verify is green, delete the file copies the plugin"
      echo "[dry-run]     supersedes (see plugin-superseded-files.txt; backup keeps copies):"
      sed 's/#.*//; /^[[:space:]]*$/d; s|^|[dry-run]       - .claude/|' \
        "$SRC/.claude/plugin-superseded-files.txt"
    fi
  fi
  report_custom_settings
  echo
  echo "[dry-run] no changes made."
  exit 0
fi

# Back up the existing .claude/.
BACKUP=".claude.pre-upgrade-${OLD_VERSION:-unknown}"
if [ -e "$BACKUP" ]; then
  n=1; while [ -e "${BACKUP}.${n}" ]; do n=$((n+1)); done; BACKUP="${BACKUP}.${n}"
fi
cp -R .claude "$BACKUP"

# Emit the settings report before we replace anything.
report_custom_settings

# OVERLAY, not swap (v0.2.8 — the v0.2.0 swap DESTROYED every custom file a
# consumer kept in .claude/: custom rules, scripts/, .macf/, hooks, edited
# CLAUDE.md. Post-incident model:
#   - template-owned files are UPDATED IN PLACE (every file the fresh init
#     generated in $WORK), except KEEP_IF_PRESENT files that hold user content
#   - files the template REMOVED on purpose are deleted per the manifest
#     ($SRC/.claude/removed-files.txt) — the backup keeps copies
#   - EVERYTHING ELSE in .claude/ is user content and is NOT TOUCHED.
KEEP_IF_PRESENT="CLAUDE.md rules/project-conventions.md"

( cd "$WORK/.claude" && find . -type f | sed 's|^\./||' ) | while IFS= read -r f; do
  case " $KEEP_IF_PRESENT " in
    *" $f "*) [ -e ".claude/$f" ] && continue ;;
  esac
  mkdir -p ".claude/$(dirname "$f")"
  cp -p "$WORK/.claude/$f" ".claude/$f"
done

# The fresh template CLAUDE.md (profile appends included) goes NEXT TO the old
# copy in the backup for manual merge — never over the user's live file.
if [ -e ".claude/CLAUDE.md" ] && ! diff -q "$WORK/.claude/CLAUDE.md" ".claude/CLAUDE.md" >/dev/null 2>&1; then
  cp -p "$WORK/.claude/CLAUDE.md" "$BACKUP/CLAUDE.md.template-new" 2>/dev/null || true
fi

# Deliberate removals (renames/deletions across template versions). The backup
# taken above already holds copies, so no stash is needed. Plugin-superseded
# paths are NOT applied here — they are conditional on the verify (see
# dedupe_plugin_superseded).
REMOVED_LIST="$(apply_removal_manifest "$SRC/.claude/removed-files.txt" "")"

# Migrations are removals whose CONTENT MOVED (v0.4: always-on rules -> AGENTS.md).
# They are reported separately and loudly: a consumer who reads `git status`, sees
# eight deletions and runs `git checkout` re-creates a stale second copy of text
# that now lives in AGENTS.md. That happened in the field; hence the warning.
MIGRATED_LIST="$(apply_removal_manifest "$SRC/.claude/migrated-files.txt" "")"

# Root-level template files: regenerate the declared .example files. The user's
# live .mcp.json / k8s-mcp.toml are never listed and never touched.
for f in $ROOT_FILES; do
  if [ -f "$WORK/$f" ]; then cp "$WORK/$f" "./$f"; fi
done

# --- AGENTS.md migration (v0.4.0) ------------------------------------------
# The always-on rules now live in AGENTS.md, which Codex and OpenCode read
# natively and Claude Code reads through the `@AGENTS.md` import in CLAUDE.md.
# $WORK already holds a freshly composed AGENTS.md for this profile.
#
# ONLY the fenced managed region is replaced. Everything the user wrote outside
# the fences survives, and a repo whose AGENTS.md has no fences (hand-written
# before this version) is NEVER overwritten — its generated copy goes to the
# backup for manual merge. Same contract as CLAUDE.md (D49).
AGENTS_BEGIN="<!-- BEGIN template-managed — regenerated by upgrade; edits here are lost -->"
AGENTS_END="<!-- END template-managed -->"

migrate_agents_md() {
  [ -f "$WORK/AGENTS.md" ] || return 0
  local managed
  managed="$(awk -v b="$AGENTS_BEGIN" -v e="$AGENTS_END" '
    index($0, b) { p=1 } p { print } index($0, e) { exit }
  ' "$WORK/AGENTS.md")"
  [ -n "$managed" ] || return 0

  if [ ! -f AGENTS.md ]; then
    cp "$WORK/AGENTS.md" AGENTS.md
    AGENTS_NOTE="  AGENTS.md:   created — the shared rules corpus every harness reads"
  elif grep -qF "$AGENTS_BEGIN" AGENTS.md; then
    printf '%s\n' "$managed" > .agents-managed.tmp
    awk -v b="$AGENTS_BEGIN" -v e="$AGENTS_END" -v f=".agents-managed.tmp" '
      index($0, b) { while ((getline line < f) > 0) print line; close(f); skip=1; next }
      index($0, e) { skip=0; next }
      !skip { print }
    ' AGENTS.md > AGENTS.md.new && mv AGENTS.md.new AGENTS.md
    rm -f .agents-managed.tmp
    AGENTS_NOTE="  AGENTS.md:   managed region refreshed (your own sections untouched)"
  else
    cp "$WORK/AGENTS.md" "$BACKUP/AGENTS.md.template-new" 2>/dev/null || true
    AGENTS_NOTE="  AGENTS.md:   YOURS, left alone — no template fences found. The generated
               version is at $BACKUP/AGENTS.md.template-new; merge what you want."
  fi

  # CLAUDE.md gets the import shim only if it has none and holds no user content
  # beyond the old template stub. Anything else is the user's file (D49).
  if [ -f "$WORK/CLAUDE.md" ] && ! grep -q '^@AGENTS.md' CLAUDE.md 2>/dev/null; then
    if [ ! -f CLAUDE.md ]; then
      cp "$WORK/CLAUDE.md" CLAUDE.md
    else
      cp "$WORK/CLAUDE.md" "$BACKUP/CLAUDE.md.shim-new" 2>/dev/null || true
      AGENTS_NOTE="$AGENTS_NOTE
  CLAUDE.md:   left alone — add '@AGENTS.md' at the top so Claude reads the shared
               corpus (a ready copy is at $BACKUP/CLAUDE.md.shim-new)."
    fi
  fi
}
AGENTS_NOTE=""
migrate_agents_md

# Ensure the backup directory is gitignored.
if [ -f .gitignore ] && ! grep -q '^\.claude\.pre-upgrade-' .gitignore; then
  printf '\n# Template upgrade backups\n.claude.pre-upgrade-*/\n' >> .gitignore
fi

# Runs AFTER the overlay (it needs the regenerated settings.json, and the CLI's
# writes must not be clobbered) and BEFORE the summary, so its progress lines
# stay in context. It cannot abort: `set +e` is scoped inside. The summary
# below therefore ALWAYS prints.
ensure_plugins

echo
echo "Upgraded ${OLD_VERSION:-unknown} -> ${NEW_VERSION} (profile: $PROFILE)."
echo "  Backup:    $BACKUP/ (your previous .claude/ — gitignored; delete once satisfied)"
[ -n "$AGENTS_NOTE" ] && printf '%s\n' "$AGENTS_NOTE"
echo "  Untouched: .claude/CLAUDE.md, rules/project-conventions.md, settings.local.json, audit.log,"
echo "             session-reports/, and every custom file you added under .claude/"
echo "  Merged:    template-owned files updated in place; fresh template CLAUDE.md (with this"
echo "             profile's appends) saved to $BACKUP/CLAUDE.md.template-new for manual merge"

# --- change manifest (v0.4.8) ----------------------------------------------
# An upgrade that changes twenty files and prints nothing is indistinguishable
# from one that changed none. Report what moved, what went, and what to do about
# the deletions git will now show as unstaged.
if [ -n "$MIGRATED_LIST" ]; then
  echo
  echo "  MIGRATED into AGENTS.md — content MOVED, not retired:"
  printf '%s\n' "$MIGRATED_LIST" | sed '/^$/d; s|^|    .claude/|'
  echo "    Claude reads them through the '@AGENTS.md' import in ./CLAUDE.md; Codex and"
  echo "    OpenCode read AGENTS.md natively. Nothing was lost."
  echo "    ** Do NOT 'git checkout' these paths. ** They are still in HEAD, so git will show"
  echo "    them as unstaged deletions — restoring them re-creates a stale second copy of the"
  echo "    same corpus, which can win over AGENTS.md. Stage the removals instead:"
  echo "        git add -u .claude/rules/"
fi
if [ -n "$REMOVED_LIST" ]; then
  echo
  echo "  REMOVED by this template version (retired; copies remain in $BACKUP/):"
  printf '%s\n' "$REMOVED_LIST" | sed '/^$/d; s|^|    .claude/|'
fi
if [ -f .claude/CLAUDE.md ] && grep -qE '^\s*-\s*`(autonomous-work|pr-discipline|writing-quality|citation-discipline|knowledge-work-structure|session-logging|prompt-shaping|reading-before-editing)\.md`' .claude/CLAUDE.md 2>/dev/null; then
  echo
  echo "  STALE DOC: .claude/CLAUDE.md still lists rules that moved into AGENTS.md."
  echo "    It is your file, so the upgrade never rewrites it — but it now documents a layout"
  echo "    that no longer exists. Fix the 'Rules applied' section (see $BACKUP/CLAUDE.md.template-new)."
fi
echo
echo "  Review the settings report above (if any) and the backup before committing."

# The scaffold upgrade SUCCEEDED and is fully reported above. Only now do we
# surface the plugin failure and exit nonzero, so fleet-upgrade.sh's per-repo log
# holds the complete report AND the row says FAILED.
if [ "$PLUGIN_RC" -ne 0 ]; then
  echo
  echo "PLUGIN STEP FAILED — the scaffold upgrade above is COMPLETE and SAFE; the plugins are not."
  printf '%s\n' "$PLUGIN_DIAG"
  exit 4
fi
