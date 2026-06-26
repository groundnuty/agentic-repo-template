#!/usr/bin/env bash
#
# bootstrap.sh — initialize the CURRENT directory from agentic-repo-template.
#
# Drops the template's .claude/ tree (and .gitignore, if you don't already have
# one) into the current directory and runs .claude/init.sh <profile>. Works in
# any directory — empty or with content, git repo or not. This is the one-command
# equivalent of: clone the template, copy .claude/, run init.sh, clean up.
#
# Usage:
#   bash bootstrap.sh <info|research|paper|paper-latex|code> [options]
#
# Options:
#   --ref <tag>      Template version to fetch (default: main = latest release).
#                    e.g. --ref v0.1.17
#   --force          Overlay even if a .claude/ already exists here. Without this,
#                    bootstrap refuses to touch a directory that's already configured.
#   --cloud-compat   Pass through to init.sh (deprecated; base is cloud-safe since v0.1.15).
#   --strict-sandbox Pass through to init.sh (opt-in hard sandbox gate).
#   --dry-run        Pass through to init.sh.
#   -h, --help       Show this help.
#
# Recommended (inspect-first) two-step:
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh -o /tmp/arp-bootstrap.sh
#   bash /tmp/arp-bootstrap.sh research
#
# Convenience one-liner (auto-executes remote code — use only if you trust the source):
#   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/bootstrap.sh | bash -s -- research

set -euo pipefail

REPO="groundnuty/agentic-repo-template"
# ARP_BOOTSTRAP_SOURCE lets tests (or forks) point at a local directory or
# alternate git URL. If it's a directory containing .claude/, files are copied
# from it directly (no clone). Otherwise it's treated as a git URL to clone.
SOURCE="${ARP_BOOTSTRAP_SOURCE:-https://github.com/${REPO}.git}"

PROFILE=""
REF="main"
FORCE=0
PASSTHROUGH=()

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; $d'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --ref)   REF="${2:?--ref needs a value}"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --cloud-compat|--strict-sandbox|--dry-run|--keep-profiles)
      PASSTHROUGH+=("$1"); shift ;;
    -*) echo "bootstrap: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *)
      if [ -z "$PROFILE" ]; then PROFILE="$1"; shift
      else echo "bootstrap: unexpected argument '$1'" >&2; exit 2; fi
      ;;
  esac
done

if [ -z "$PROFILE" ]; then
  echo "bootstrap: profile argument required (info|research|paper|paper-latex|code)" >&2
  usage >&2
  exit 2
fi

if [ -e .claude ] && [ "$FORCE" -ne 1 ]; then
  echo "bootstrap: .claude/ already exists in $(pwd)." >&2
  echo "           Refusing to overlay an already-configured repo. Re-run with --force to overlay," >&2
  echo "           or remove .claude/ first. (To upgrade an existing repo, see README → Upgrading.)" >&2
  exit 1
fi

# Resolve the source tree: local directory (copy) or git URL (shallow clone).
SCRATCH=""
cleanup() { [ -n "$SCRATCH" ] && rm -rf "$SCRATCH"; return 0; }
trap cleanup EXIT

if [ -d "$SOURCE" ] && [ -d "$SOURCE/.claude" ]; then
  SRC_DIR="$SOURCE"
else
  command -v git >/dev/null 2>&1 || { echo "bootstrap: git not found on PATH." >&2; exit 3; }
  SCRATCH="$(mktemp -d)"
  if ! git clone --depth=1 --branch "$REF" "$SOURCE" "$SCRATCH" >/dev/null 2>&1; then
    echo "bootstrap: failed to clone $SOURCE at ref '$REF'." >&2
    exit 3
  fi
  SRC_DIR="$SCRATCH"
fi

if [ ! -d "$SRC_DIR/.claude" ]; then
  echo "bootstrap: source has no .claude/ directory ($SRC_DIR)." >&2
  exit 3
fi

# Copy config into the current directory.
cp -R "$SRC_DIR/.claude" .
# Only seed .gitignore if the user doesn't already have one.
if [ ! -f .gitignore ] && [ -f "$SRC_DIR/.gitignore" ]; then
  cp "$SRC_DIR/.gitignore" .
fi

# Hand off to init.sh, forwarding any pass-through flags.
bash ./.claude/init.sh "$PROFILE" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}

echo
echo "bootstrap: done. Current directory initialized from $REPO ($REF), profile \"$PROFILE\"."
