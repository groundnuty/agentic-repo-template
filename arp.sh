#!/usr/bin/env bash
#
# arp — agentic-repo-template CLI. Install once, use everywhere.
#
#   arp init -p research          initialize THIS directory (any local dir; no GitHub needed)
#   arp init -p paper ~/papers/x  ...or that one
#   arp upgrade                   upgrade this repo to the latest template
#   arp fleet ~/repos             report every template repo under a root
#   arp fleet --apply ~/repos     upgrade them all
#   arp status                    what this repo is running (version, profile, plugins)
#   arp profiles                  the five profiles, one line each
#   arp update                    refresh the cached template (do this to get new releases)
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/arp.sh \
#     -o ~/.local/bin/arp && chmod +x ~/.local/bin/arp
#   (ensure ~/.local/bin is on PATH)
#
# Global options: --ref <tag> (pin a template version) · -h|--help · --version
# Env: ARP_SOURCE=/path/to/template-checkout  (bypass the cache — for template development)
#      ARP_CACHE=~/.cache/arp                 (where the template clone lives)

set -euo pipefail

REPO="groundnuty/agentic-repo-template"
CACHE="${ARP_CACHE:-$HOME/.cache/arp}"
TREE="$CACHE/template"
REF="main"

die()  { echo "arp: $*" >&2; exit 1; }
info() { echo "arp: $*"; }

usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'; }

# The template tree we run from: an explicit ARP_SOURCE, else the cache (cloned
# on first use). Everything else in this script reuses the scripts inside it,
# so `arp` never duplicates init/upgrade/fleet logic.
ensure_tree() {
  if [ -n "${ARP_SOURCE:-}" ]; then
    [ -d "$ARP_SOURCE/.claude" ] || die "ARP_SOURCE=$ARP_SOURCE has no .claude/"
    TREE="$ARP_SOURCE"; return 0
  fi
  if [ ! -d "$TREE/.claude" ]; then
    command -v git >/dev/null || die "git is required for the first fetch"
    info "fetching the template (once) into $TREE …"
    mkdir -p "$CACHE"
    git clone -q --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$TREE" \
      || die "could not clone $REPO at '$REF'"
  fi
}

tree_version() { grep '^TEMPLATE_VERSION=' "$TREE/.claude/init.sh" | head -1 | sed 's/.*"\(.*\)".*/\1/'; }

cmd_update() {
  ensure_tree
  [ -n "${ARP_SOURCE:-}" ] && { info "ARP_SOURCE is set — nothing to update"; return 0; }
  info "updating $TREE …"
  git -C "$TREE" fetch -q --depth 1 origin "$REF" && git -C "$TREE" reset -q --hard FETCH_HEAD
  info "template is now $(tree_version)"
}

cmd_init() {
  local profile="" dir="."
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--profile) profile="${2:?-p needs a profile}"; shift 2 ;;
      -p=*|--profile=*) profile="${1#*=}"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) PASS_THROUGH+=("$1"); shift ;;
      *) if [ -z "$profile" ]; then profile="$1"; else dir="$1"; fi; shift ;;
    esac
  done
  [ -n "$profile" ] || die "which profile? e.g. arp init -p research   (arp profiles lists them)"
  case "$profile" in info|research|paper|paper-latex|code) ;;
    *) die "unknown profile '$profile' — one of: info research paper paper-latex code" ;; esac
  [ -d "$dir" ] || die "no such directory: $dir"
  ensure_tree
  info "initializing $(cd "$dir" && pwd -P) as '$profile' (template $(tree_version))"
  ( cd "$dir" && ARP_BOOTSTRAP_SOURCE="$TREE" bash "$TREE/bootstrap.sh" "$profile" \
      ${PASS_THROUGH[@]+"${PASS_THROUGH[@]}"} )
}

cmd_upgrade() {
  local dir="."
  while [ $# -gt 0 ]; do
    case "$1" in -h|--help) usage; exit 0 ;; -*) PASS_THROUGH+=("$1"); shift ;; *) dir="$1"; shift ;; esac
  done
  [ -f "$dir/.claude/.template-version" ] || die "$dir is not a template repo (no .claude/.template-version). Use: arp init -p <profile>"
  ensure_tree
  ( cd "$dir" && ARP_UPGRADE_SOURCE="$TREE" bash "$TREE/upgrade.sh" ${PASS_THROUGH[@]+"${PASS_THROUGH[@]}"} )
}

cmd_fleet() {
  ensure_tree
  ARP_UPGRADE_SOURCE="$TREE" bash "$TREE/fleet-upgrade.sh" "$@"
}

cmd_status() {
  local dir="${1:-.}"
  local stamp="$dir/.claude/.template-version"
  [ -f "$stamp" ] || die "$dir is not a template repo. Use: arp init -p <profile>"
  local v p
  v="$({ grep '^version=' "$stamp" || true; } | head -1 | cut -d= -f2)"
  p="$({ grep '^profile=' "$stamp" || true; } | head -1 | cut -d= -f2)"
  echo "repo:     $(cd "$dir" && pwd -P)"
  echo "profile:  $p"
  echo "template: $v"
  if [ -z "${ARP_NO_FETCH:-}" ] && ensure_tree 2>/dev/null; then
    local latest; latest="$(tree_version)"
    if [ "$v" = "$latest" ]; then echo "          up to date"
    else echo "          cached template is $latest — 'arp upgrade' to move (run 'arp update' first for newer)"; fi
  fi
  # Declared capability plugins, and whether they are actually installed HERE.
  if command -v jq >/dev/null && [ -f "$dir/.claude/settings.json" ]; then
    local declared; declared="$(jq -r '(.enabledPlugins // {}) | keys[] | select(endswith("@agentic-plugins"))' "$dir/.claude/settings.json" 2>/dev/null || true)"
    if [ -n "$declared" ]; then
      local here=""
      command -v claude >/dev/null && here="$(cd "$dir" && claude plugin list --json 2>/dev/null | jq -r --arg p "$(cd "$dir" && pwd -P)" '[.[] | select(.projectPath == $p and .enabled == true) | .id][]' 2>/dev/null || true)"
      while IFS= read -r d; do
        [ -n "$d" ] || continue
        if printf '%s\n' "$here" | grep -qxF "$d"; then echo "plugin:   $d — installed"
        else echo "plugin:   $d — NOT INSTALLED (run: arp upgrade, or claude plugin install $d --scope project)"; fi
      done <<EOF
$declared
EOF
    fi
  fi
}

cmd_profiles() {
  cat <<'EOF'
info         minimal base — rules, session logging, checkpoints. Any repo.
research     info + knowledge-work dirs, citation discipline, PDF reading. The thinking-session default.
paper        research + the agentic-paper plugin: review, claim verification, proofreading, referees.
paper-latex  paper + LaTeX/BibTeX discipline, TikZ skill, texlab LSP.
code         info + Makefile/devbox conventions, testing discipline.

  arp init -p research          initialize the current directory
EOF
}

PASS_THROUGH=()
# Global flags may appear before the subcommand.
while [ $# -gt 0 ]; do
  case "${1:-}" in
    --ref) REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --version) ensure_tree >/dev/null 2>&1 && echo "template $(tree_version) (cache: $TREE)" || echo "template: not fetched yet"; exit 0 ;;
    *) break ;;
  esac
done

case "${1:-}" in
  init)     shift; cmd_init "$@" ;;
  upgrade)  shift; cmd_upgrade "$@" ;;
  fleet)    shift; cmd_fleet "$@" ;;
  status)   shift; cmd_status "$@" ;;
  profiles) shift; cmd_profiles ;;
  update)   shift; cmd_update ;;
  ""|help)  usage ;;
  *)        die "unknown command '$1' — try: arp help" ;;
esac
