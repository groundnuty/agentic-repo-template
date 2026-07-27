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

# Deliberate removals (renames/deletions across template versions).
if [ -f "$SRC/.claude/removed-files.txt" ]; then
  while IFS= read -r rf; do
    case "$rf" in ""|\#*) continue ;; esac
    rm -f ".claude/$rf" 2>/dev/null || true
  done < "$SRC/.claude/removed-files.txt"
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
echo "  Backup:    $BACKUP/ (your previous .claude/ — gitignored; delete once satisfied)"
echo "  Untouched: .claude/CLAUDE.md, rules/project-conventions.md, settings.local.json, audit.log,"
echo "             session-reports/, and every custom file you added under .claude/"
echo "  Merged:    template-owned files updated in place; fresh template CLAUDE.md (with this"
echo "             profile's appends) saved to $BACKUP/CLAUDE.md.template-new for manual merge"
echo "  Review the settings report above (if any) and the backup before committing."
