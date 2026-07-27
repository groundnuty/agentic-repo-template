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
# regenerates the template-owned config from the latest release:
#   - .claude/ (settings.json, rules, skills, agents, hooks, templates, commands)
#   - .claude/CLAUDE.md (REGENERATED as of v0.2.0 — profile appends must reach
#     upgraded repos; your previous copy is in the backup, merge personal edits
#     from there; durable per-project notes belong in rules/project-conventions.md)
#   - declared root-level template files (.mcp.json.example, k8s-mcp.toml.example)
#     — your live .mcp.json is NEVER touched
# and PRESERVES: settings.local.json, rules/project-conventions.md, audit.log,
# session-reports/. The stamp is bumped to the new version.
#
# The settings report distinguishes entries the NEW TEMPLATE REMOVED (do not
# restore them) from YOUR CUSTOMIZATIONS (move to settings.local.json).
#
# Options:
#   --ref <tag>   Upgrade to a specific version instead of latest (default: main).
#   --dry-run     Show what would change without modifying anything.
#   -h, --help    Show this help.

set -euo pipefail

REPO="groundnuty/agentic-repo-template"
# ARP_UPGRADE_SOURCE: local dir (with .claude/) or git URL. Default = public repo.
SOURCE="${ARP_UPGRADE_SOURCE:-https://github.com/${REPO}.git}"
REF="main"
DRY_RUN=0

# Root-level template-owned files (regenerated on upgrade). Live user files
# (.mcp.json without .example) are never listed here and never touched.
ROOT_FILES=".mcp.json.example k8s-mcp.toml.example"

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

if [ -n "$OLD_VERSION" ] && [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
  echo "Already up to date. Nothing to do."
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
(cd "$WORK" && bash ./.claude/init.sh "$PROFILE" ${FLAGS[@]+"${FLAGS[@]}"} >/dev/null)

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
  for sec in enabledPlugins marketplaces env hooks; do
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
  echo "[dry-run] would regenerate: .claude/ (incl. CLAUDE.md), root files: $ROOT_FILES"
  echo "[dry-run] would preserve:   settings.local.json, rules/project-conventions.md, audit.log, session-reports/"
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

# Assemble the final tree INSIDE $WORK first (copy preserved user files into it),
# then swap. This closes the non-atomic window where a crash between removal and
# restore could strand user files outside the repo.
preserve_paths="settings.local.json rules/project-conventions.md audit.log"
for f in $preserve_paths; do
  if [ -e ".claude/$f" ]; then
    mkdir -p "$WORK/.claude/$(dirname "$f")"
    rm -rf "$WORK/.claude/${f:?}"
    cp -R ".claude/$f" "$WORK/.claude/$f"
  fi
done
if [ -d .claude/session-reports ]; then
  rm -rf "$WORK/.claude/session-reports"
  cp -R .claude/session-reports "$WORK/.claude/session-reports"
fi

OLD_TREE=".claude.upgrade-old.$$"
mv .claude "$OLD_TREE"
if mv "$WORK/.claude" .claude; then
  rm -rf "$OLD_TREE"
else
  mv "$OLD_TREE" .claude
  echo "upgrade: swap failed; original .claude/ restored (backup at $BACKUP/)." >&2
  exit 4
fi

# Root-level template files: regenerate the declared .example files. The user's
# live .mcp.json / k8s-mcp.toml are never listed and never touched.
for f in $ROOT_FILES; do
  if [ -f "$WORK/$f" ]; then cp "$WORK/$f" "./$f"; fi
done

# Ensure the backup directory is gitignored.
if [ -f .gitignore ] && ! grep -q '^\.claude\.pre-upgrade-' .gitignore; then
  printf '\n# Template upgrade backups\n.claude.pre-upgrade-*/\n' >> .gitignore
fi

echo
echo "Upgraded ${OLD_VERSION:-unknown} -> ${NEW_VERSION} (profile: $PROFILE)."
echo "  Backup:      $BACKUP/ (your previous .claude/ — gitignored; delete once satisfied)"
echo "  Preserved:   settings.local.json, rules/project-conventions.md, audit.log, session-reports/"
echo "  Regenerated: .claude/CLAUDE.md (previous copy in the backup — merge any personal edits;"
echo "               durable notes belong in rules/project-conventions.md), root: $ROOT_FILES"
echo "  Review the settings report above (if any) and the backup before committing."
