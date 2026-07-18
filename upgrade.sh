#!/usr/bin/env bash
#
# upgrade.sh — upgrade an already-initialized repo to the latest template version.
#
# Reads .claude/.template-version to learn the repo's profile and sandbox flags,
# so you don't have to remember them. One command, no arguments:
#
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh | bash
#
# It backs up the existing .claude/ to .claude.pre-upgrade-<oldversion>/,
# regenerates the template-owned config from the latest release (settings.json,
# skills/agents/hooks/templates/commands, profile rules, refresh-skills.sh),
# and PRESERVES your files: settings.local.json, rules/project-conventions.md,
# .claude/CLAUDE.md, audit.log, session-reports/. The stamp is bumped to the
# new version. Any custom keys you added directly to .claude/settings.json are
# reported (move them to settings.local.json — that's the intended home for
# overrides).
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

stamp_get() { grep "^$1=" "$STAMP" | head -1 | cut -d= -f2-; }
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
SCRATCH=""; WORK=""; PRESERVE=""
cleanup() { rm -rf ${SCRATCH:+"$SCRATCH"} ${WORK:+"$WORK"} ${PRESERVE:+"$PRESERVE"} 2>/dev/null; return 0; }
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
# profile + flags.
WORK="$(mktemp -d)"
cp -R "$SRC/.claude" "$WORK/"
FLAGS=()
[ "$CLOUD_COMPAT" = "true" ] && FLAGS+=(--cloud-compat)
[ "$STRICT_SANDBOX" = "true" ] && FLAGS+=(--strict-sandbox)
(cd "$WORK" && bash ./.claude/init.sh "$PROFILE" ${FLAGS[@]+"${FLAGS[@]}"} >/dev/null)

# Report custom entries in the existing settings.json that aren't in the freshly
# generated one. NOTE: this set includes both your customizations AND entries the
# new version intentionally removed — cross-reference the CHANGELOG above.
report_custom_settings() {
  local old=".claude/settings.json" new="$WORK/.claude/settings.json" any=0
  [ -f "$old" ] && [ -f "$new" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local p
  for p in ".permissions.allow" ".permissions.deny" ".permissions.ask" ".sandbox.excludedCommands"; do
    local d
    d="$(jq -rn --slurpfile o "$old" --slurpfile n "$new" \
      "((\$o[0]|$p//[]) - (\$n[0]|$p//[]))[]" 2>/dev/null || true)"
    if [ -n "$d" ]; then
      [ "$any" -eq 0 ] && { echo; echo "settings.json entries in your current config but not in the new template output"; echo "(these are your customizations OR entries the new version removed — see CHANGELOG):"; any=1; }
      echo "  $p:"; echo "$d" | sed 's/^/    - /'
    fi
  done
  local oldhooks
  oldhooks="$(jq -rn --slurpfile o "$old" --slurpfile n "$new" \
    '(($o[0].hooks//{})|keys) - (($n[0].hooks//{})|keys) | .[]' 2>/dev/null || true)"
  if [ -n "$oldhooks" ]; then
    [ "$any" -eq 0 ] && echo
    echo "  hook events only in your current config:"; echo "$oldhooks" | sed 's/^/    - /'
    any=1
  fi
  [ "$any" -eq 1 ] && echo "  -> move genuine customizations into .claude/settings.local.json (preserved across upgrades)."
  return 0
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "[dry-run] would back up .claude/ -> .claude.pre-upgrade-${OLD_VERSION:-unknown}/"
  echo "[dry-run] would regenerate: settings.json, skills/ agents/ hooks/ templates/ commands/, profile rules, refresh-skills.sh, .template-version"
  echo "[dry-run] would preserve:   settings.local.json, rules/project-conventions.md, .claude/CLAUDE.md, audit.log, session-reports/"
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

# Emit the custom-settings report against the backup before we replace.
report_custom_settings

# Stash user-owned files, replace .claude with the fresh tree, restore them.
PRESERVE="$(mktemp -d)"
preserve_paths="settings.local.json CLAUDE.md rules/project-conventions.md audit.log"
for f in $preserve_paths; do
  if [ -e ".claude/$f" ]; then mkdir -p "$PRESERVE/$(dirname "$f")"; cp -R ".claude/$f" "$PRESERVE/$f"; fi
done
[ -d .claude/session-reports ] && cp -R .claude/session-reports "$PRESERVE/session-reports"

rm -rf .claude
cp -R "$WORK/.claude" .claude

for f in $preserve_paths; do
  if [ -e "$PRESERVE/$f" ]; then mkdir -p ".claude/$(dirname "$f")"; cp -R "$PRESERVE/$f" ".claude/$f"; fi
done
if [ -d "$PRESERVE/session-reports" ]; then rm -rf .claude/session-reports; cp -R "$PRESERVE/session-reports" .claude/session-reports; fi

# Ensure the backup directory is gitignored.
if [ -f .gitignore ] && ! grep -q '^\.claude\.pre-upgrade-' .gitignore; then
  printf '\n# Template upgrade backups\n.claude.pre-upgrade-*/\n' >> .gitignore
fi

echo
echo "Upgraded ${OLD_VERSION:-unknown} -> ${NEW_VERSION} (profile: $PROFILE)."
echo "  Backup:    $BACKUP/ (your previous .claude/ — gitignored; delete once satisfied)"
echo "  Preserved: settings.local.json, rules/project-conventions.md, .claude/CLAUDE.md, audit.log, session-reports/"
echo "  Review the settings.json report above (if any) and the backup before committing."
