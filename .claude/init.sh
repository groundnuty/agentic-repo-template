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
# merges skills.manifest.json entries, then removes profiles/ and init.sh.
#
# With --cloud-compat (no profile), runs in patch-only mode against an already-
# initialized .claude/settings.json — useful for upgrading existing repos to be
# compatible with Claude Code on the web's nested sandbox.

set -eu

VALID_PROFILES=(info research paper paper-latex code)
JQ="${JQ:-jq}"
TEMPLATE_VERSION="v0.1.16"

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

copy_profile_content() {
  local profile_dir="$1"
  # Copy any of: rules/, skills/, agents/, hooks/, templates/ that exist in the profile.
  for subdir in rules skills agents hooks templates; do
    if [ -d "$profile_dir/$subdir" ]; then
      mkdir -p ".claude/$subdir"
      cp -R "$profile_dir/$subdir/." ".claude/$subdir/"
    fi
  done
}

# Kept for backward-compat with older test expectations.
copy_rules_and_skills() {
  copy_profile_content "$1"
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
  local dest=".claude/skills.manifest.json"
  [ -f "$dest" ] || echo '{"skills": []}' > "$dest"
  local tmp
  tmp=$(mktemp)
  "$JQ" -s '{ skills: (.[0].skills + .[1].skills) }' "$dest" "$src" > "$tmp"
  mv "$tmp" "$dest"
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

  for p in $chain; do
    profile_dir=".claude/profiles/$p"
    [ -d "$profile_dir" ] || { echo "profile dir missing: $profile_dir" >&2; exit 4; }

    if [ "$dry_run" = "1" ]; then
      echo "[dry-run] would merge $profile_dir/settings.overlay.json"
      echo "[dry-run] would copy $profile_dir/rules/ and $profile_dir/skills/"
      echo "[dry-run] would append $profile_dir/CLAUDE.append.md"
      echo "[dry-run] would merge $profile_dir/skills.manifest.json"
      continue
    fi

    apply_settings_overlay "$profile_dir"
    copy_rules_and_skills "$profile_dir"
    append_claude_md "$profile_dir"
    merge_skills_manifest "$profile_dir"
  done

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
    if [ "$keep_profiles" = "1" ]; then
      echo "  profiles/ and init.sh retained (--keep-profiles)."
    else
      echo "  profiles/ and init.sh removed (self-cleaned)."
    fi
  fi
}

main "$@"
