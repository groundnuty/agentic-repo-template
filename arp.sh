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
#   arp overview                  ALL hosts at a glance: repos, versions, drift  <-- the fleet view
#   arp hosts                     which hosts overview surveys (edit the list)
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
#      ARP_HOSTS=~/.config/arp/hosts.conf     (host list for `overview`)
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

HOSTS_CONF="${ARP_HOSTS:-$HOME/.config/arp/hosts.conf}"

# Survey one host. Runs a self-contained snippet over ssh — the remote side does
# NOT need arp, jq, or anything but POSIX sh + find. Emits TSV:
#   host <TAB> repo <TAB> version <TAB> profile <TAB> dirty
survey_snippet() {
  cat <<'SNIP'
for root in ROOTS_PLACEHOLDER; do
  r=$(eval echo "$root"); r=$(cd "$r" 2>/dev/null && pwd -P) || continue
  find "$r" -maxdepth 5 -name .template-version -path '*/.claude/*' 2>/dev/null | while read -r st; do
    d=${st%/.claude/.template-version}
    v=$(grep '^version=' "$st" 2>/dev/null | head -1 | cut -d= -f2)
    p=$(grep '^profile=' "$st" 2>/dev/null | head -1 | cut -d= -f2)
    n=$(cd "$d" 2>/dev/null && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\n' "$d" "${v:-?}" "${p:-?}" "${n:-–}"
  done
done
SNIP
}

survey_host() {
  local host="$1" roots="$2" snip
  snip="$(survey_snippet | sed "s|ROOTS_PLACEHOLDER|$roots|")"
  if [ "$host" = "local" ]; then
    printf '%s\n' "$snip" | sh 2>/dev/null | sed "s|^|local\t|"
  else
    ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" "sh -s" <<< "$snip" 2>/dev/null | sed "s|^|$host\t|"
  fi
}

cmd_hosts() {
  if [ ! -f "$HOSTS_CONF" ]; then
    mkdir -p "$(dirname "$HOSTS_CONF")"
    cat > "$HOSTS_CONF" <<'HC'
# Hosts that `arp overview` surveys. One per line:  <ssh-host-or-"local">  <roots…>
# Roots are shell-expanded on the remote side (~ works). Lines starting with # are ignored.
# Only list hosts that actually hold repos — this is not an infrastructure inventory.
local     ~/repos
HC
    info "created $HOSTS_CONF — add your hosts, then: arp overview"
  fi
  echo "# $HOSTS_CONF"
  grep -vE '^\s*(#|$)' "$HOSTS_CONF" | sed 's/^/  /'
  echo
  echo "edit that file to add hosts, e.g.:  magent    ~/repos"
}

cmd_overview() {
  [ -f "$HOSTS_CONF" ] || cmd_hosts >/dev/null
  ensure_tree 2>/dev/null || true
  local latest=""; [ -d "$TREE/.claude" ] && latest="$(tree_version)"
  local raw; raw="$(mktemp)"; trap 'rm -f "$raw"' RETURN
  local host roots
  while read -r host roots; do
    case "$host" in ''|\#*) continue ;; esac
    survey_host "$host" "$roots" >> "$raw" &
  done < <(grep -vE '^\s*(#|$)' "$HOSTS_CONF")
  wait

  [ -s "$raw" ] || { echo "no template repos found on any configured host (arp hosts)"; return 0; }

  echo "arp overview — template ${latest:-?} is current"
  echo
  printf '%-12s %6s %8s %8s %7s  %s\n' "HOST" "REPOS" "CURRENT" "BEHIND" "DIRTY" "PROFILES"
  local hosts_seen; hosts_seen="$(cut -f1 "$raw" | sort -u)"
  local h n cur beh dirty profs
  while IFS= read -r h; do
    n=$(awk -F'\t' -v h="$h" '$1==h' "$raw" | wc -l | tr -d ' ')
    cur=$(awk -F'\t' -v h="$h" -v L="$latest" '$1==h && $3==L' "$raw" | wc -l | tr -d ' ')
    beh=$((n - cur))
    dirty=$(awk -F'\t' -v h="$h" '$1==h && $5 ~ /^[0-9]+$/ && $5+0 > 0' "$raw" | wc -l | tr -d ' ')
    profs=$(awk -F'\t' -v h="$h" '$1==h {print $4}' "$raw" | sort | uniq -c | sort -rn | awk '{printf "%s:%s ", $2, $1}')
    printf '%-12s %6s %8s %8s %7s  %s\n' "$h" "$n" "$cur" "$beh" "$dirty" "$profs"
  done <<< "$hosts_seen"
  printf '%-12s %6s %8s %8s %7s\n' "TOTAL" \
    "$(wc -l < "$raw" | tr -d ' ')" \
    "$(awk -F'\t' -v L="$latest" '$3==L' "$raw" | wc -l | tr -d ' ')" \
    "$(awk -F'\t' -v L="$latest" '$3!=L' "$raw" | wc -l | tr -d ' ')" \
    "$(awk -F'\t' '$5 ~ /^[0-9]+$/ && $5+0 > 0' "$raw" | wc -l | tr -d ' ')"

  if [ -n "$latest" ] && awk -F'\t' -v L="$latest" '$3!=L' "$raw" | grep -q .; then
    echo
    echo "behind $latest:"
    awk -F'\t' -v L="$latest" '$3!=L {printf "  %-10s %-8s %s\n", $1, $3, $2}' "$raw" | sort | head -40
    echo
    echo "  fix:  arp fleet --apply <root>          (locally)"
    echo "        ssh <host> 'arp fleet --apply <root>'  (elsewhere — or run arp there)"
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
  overview) shift; cmd_overview ;;
  hosts)    shift; cmd_hosts ;;
  profiles) shift; cmd_profiles ;;
  update)   shift; cmd_update ;;
  ""|help)  usage ;;
  *)        die "unknown command '$1' — try: arp help" ;;
esac
