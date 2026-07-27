#!/usr/bin/env bash
#
# fleet-upgrade.sh — upgrade EVERY template-initialized repo under one or more
# root directories, in one command. The mass-migration companion to upgrade.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/fleet-upgrade.sh -o /tmp/fleet.sh
#   bash /tmp/fleet.sh ~/repos                    # REPORT ONLY (default): table of what would happen
#   bash /tmp/fleet.sh --apply ~/repos            # actually upgrade, one repo at a time
#   bash /tmp/fleet.sh --apply --skip getting-started-in-crypto ~/repos ~/work
#
# What it does per discovered repo (any dir containing .claude/.template-version):
#   - reads version+profile from the stamp; skips repos already at the target
#   - detects a LIVE Claude Code session with its cwd inside the repo and skips
#     it (upgrading under a running session invites confusion) unless --force-live
#   - in --apply mode: runs upgrade.sh (fetched once), captures a per-repo log,
#     and reports upgraded/skipped/failed at the end
#
# It never commits and never pushes — review each repo's diff yourself.
#
# Options:
#   --apply          Perform upgrades (default is report-only).
#   --ref <tag>      Upgrade to a specific version (default: main = latest).
#   --skip <name>    Skip repos whose basename matches (repeatable).
#   --force-live     Do not skip repos with a live session (not recommended).
#   --log-dir <dir>  Where per-repo logs go (default: a fresh temp dir).
#   -h, --help       This help.

set -euo pipefail

REPO="groundnuty/agentic-repo-template"
UPGRADE_URL="https://raw.githubusercontent.com/${REPO}/main/upgrade.sh"

APPLY=0; REF="main"; FORCE_LIVE=0; LOG_DIR=""
SKIP_NAMES=()
ROOTS=()

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)      APPLY=1; shift ;;
    --ref)        REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*)      REF="${1#*=}"; shift ;;
    --skip)       SKIP_NAMES+=("${2:?--skip needs a value}"); shift 2 ;;
    --force-live) FORCE_LIVE=1; shift ;;
    --log-dir)    LOG_DIR="${2:?--log-dir needs a value}"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "fleet-upgrade: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *)            ROOTS+=("$1"); shift ;;
  esac
done
[ "${#ROOTS[@]}" -gt 0 ] || { echo "fleet-upgrade: give at least one root directory." >&2; exit 2; }

# Resolve the upgrader once. ARP_UPGRADE_SOURCE (local template checkout or git
# URL) passes straight through to upgrade.sh; ARP_FLEET_UPGRADER points at a
# local upgrade.sh for offline/test use.
UPGRADER="${ARP_FLEET_UPGRADER:-}"
if [ -z "$UPGRADER" ]; then
  if [ -n "${ARP_UPGRADE_SOURCE:-}" ] && [ -f "${ARP_UPGRADE_SOURCE}/upgrade.sh" ]; then
    UPGRADER="${ARP_UPGRADE_SOURCE}/upgrade.sh"
  else
    UPGRADER="$(mktemp)"
    curl -fsSL "$UPGRADE_URL" -o "$UPGRADER" || { echo "fleet-upgrade: failed to fetch upgrade.sh" >&2; exit 3; }
  fi
fi

[ -n "$LOG_DIR" ] || LOG_DIR="$(mktemp -d)"
mkdir -p "$LOG_DIR"

# Live-session detection: any process named claude whose cwd is inside the repo.
live_session_in() {
  local repo="$1" pid cwd
  for pid in $(pgrep -x claude 2>/dev/null || true); do
    if [ -e "/proc/$pid/cwd" ]; then cwd="$(readlink "/proc/$pid/cwd" 2>/dev/null || true)"
    else cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"; fi
    case "$cwd" in "$repo"|"$repo"/*) return 0 ;; esac
  done
  return 1
}

is_skipped() {
  local base="$1" n
  for n in ${SKIP_NAMES[@]+"${SKIP_NAMES[@]}"}; do [ "$base" = "$n" ] && return 0; done
  return 1
}

# Discover stamped repos.
REPOS=()
for root in "${ROOTS[@]}"; do
  # Resolve the root physically: a symlinked root (~/repos -> Dropbox/...) is
  # common and find(1) does not descend symlinked start points.
  root="$(cd "$root" 2>/dev/null && pwd -P)" || { echo "fleet-upgrade: root not a directory: $root" >&2; exit 2; }
  while IFS= read -r stamp; do
    REPOS+=("${stamp%/.claude/.template-version}")
  done < <(find "$root" -name .template-version -path '*/.claude/*' 2>/dev/null | sort)
done
[ "${#REPOS[@]}" -gt 0 ] || { echo "fleet-upgrade: no stamped repos under: ${ROOTS[*]}" >&2; exit 1; }

echo "fleet-upgrade: ${#REPOS[@]} stamped repo(s) found. Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo report-only). Logs: $LOG_DIR"
echo

UPGRADED=0; SKIPPED=0; FAILED=0; CURRENT=0
printf '%-52s %-9s %-11s %-6s %s\n' "repo" "version" "profile" "dirty" "action"
for repo in "${REPOS[@]}"; do
  base="$(basename "$repo")"
  ver="$(grep '^version=' "$repo/.claude/.template-version" | head -1 | cut -d= -f2)"
  prof="$(grep '^profile=' "$repo/.claude/.template-version" | head -1 | cut -d= -f2)"
  dirty="$(cd "$repo" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  action=""
  if is_skipped "$base"; then
    action="SKIP (--skip)"; SKIPPED=$((SKIPPED+1))
  elif [ "$FORCE_LIVE" -eq 0 ] && live_session_in "$repo"; then
    action="SKIP (live Claude session)"; SKIPPED=$((SKIPPED+1))
  elif [ "$APPLY" -eq 0 ]; then
    action="would upgrade"
  else
    log="$LOG_DIR/${base}.log"
    if (cd "$repo" && bash "$UPGRADER" --ref "$REF" > "$log" 2>&1); then
      if grep -q "Already up to date" "$log"; then action="current"; CURRENT=$((CURRENT+1))
      else
        newv="$(grep -oE 'Upgraded .* -> [^ ]+' "$log" | head -1 | awk '{print $NF}')"
        action="UPGRADED -> ${newv:-?}"; UPGRADED=$((UPGRADED+1))
      fi
    else
      action="FAILED (see log)"; FAILED=$((FAILED+1))
    fi
  fi
  printf '%-52s %-9s %-11s %-6s %s\n' "${repo}" "$ver" "$prof" "$dirty" "$action"
done

echo
if [ "$APPLY" -eq 1 ]; then
  echo "Done: $UPGRADED upgraded, $CURRENT already current, $SKIPPED skipped, $FAILED failed."
  echo "Per-repo logs (incl. the partitioned settings reports): $LOG_DIR"
  echo "Nothing was committed or pushed — review each repo's diff and its"
  echo ".claude.pre-upgrade-* backup, then commit per repo."
  [ "$FAILED" -eq 0 ] || exit 1
else
  echo "Report only — re-run with --apply to perform the upgrades."
fi
