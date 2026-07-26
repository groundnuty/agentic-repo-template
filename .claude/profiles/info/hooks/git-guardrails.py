#!/usr/bin/env python3
"""
Git guardrails hook (PreToolUse) — opt-in.

Blocks destructive git operations before they run. This is the belt to
`permissions.deny`'s braces: the deny rules in settings.json catch the common
forms, but this hook also catches invocations that carry git's GLOBAL options
between `git` and the subcommand — `git -C /repo reset --hard`, `git -c k=v
clean -fd` — which a literal deny pattern does not match.

Blocks:
  - git reset --hard              (discards uncommitted work irrecoverably)
  - git clean -f / -fd / -fdx     (deletes UNTRACKED files, including data)
  - git push --force / -f         (clobbers remote history; --force-with-lease allowed)
  - git add -A / --all / git add .    (blanket staging can sweep in secrets)
  - git checkout -- . / git restore . (mass discard of working changes)

Enable by referencing it from `.claude/settings.local.json`:

    {
      "hooks": {
        "PreToolUse": [
          { "matcher": "Bash",
            "hooks": [{ "type": "command",
                        "command": "python3 .claude/hooks/git-guardrails.py" }] }
        ]
      }
    }

Fails OPEN: any error exits 0 with no decision, so a broken hook never wedges
the session.

Adapted from pedrohcgs/claude-code-my-workflow (MIT),
https://github.com/pedrohcgs/claude-code-my-workflow — which in turn adapted the
git-guardrails pattern from mattpocock/skills. The upstream hardcoded-path check
(warning on /Users/<u> paths in .R/.do/.qmd files) is not carried here: it is
specific to R/Stata replication packages, and this template is language-agnostic.
"""

from __future__ import annotations

import json
import re
import sys

# Git GLOBAL options that can sit between `git` and the subcommand. Without
# matching these, `git -C /repo reset --hard` bypasses every guardrail below.
_GO = (r"(?:-C\s+\S+\s+|-c\s+\S+\s+|--git-dir(?:=\S+\s+|\s+\S+\s+)|"
       r"--work-tree(?:=\S+\s+|\s+\S+\s+)|--no-pager\s+|--paginate\s+|-p\s+)*")

# (pattern, what's wrong, the safe alternative)
GIT_DENY = [
    (re.compile(r"\bgit\s+" + _GO + r"reset\s+--hard\b"),
     "git reset --hard discards uncommitted work irrecoverably.",
     "Use `git stash` (recoverable), or reset specific paths."),
    (re.compile(r"\bgit\s+" + _GO + r"clean\b.*(--force\b|(?<![\w-])-[a-z]*f)"),
     "git clean -f/--force deletes UNTRACKED files — including data not yet committed.",
     "Inspect with `git clean -n` first, then delete specific paths by hand."),
    (re.compile(r"\bgit\s+" + _GO + r"push\b.*(--force(?![\w-])|(?<!-)\s-f\b)"),
     "git push --force clobbers remote history.",
     "Use `git push --force-with-lease` if a branch genuinely must be rewritten."),
    (re.compile(r"\bgit\s+" + _GO + r"add\s+(?:--\s+)?(-A\b|--all\b|\.(?:\s|$)|:/)"),
     "Blanket staging (git add -A / . / :/) can stage secrets, data, or settings.local.json.",
     "Stage specific files: `git add path/to/file ...`."),
    (re.compile(r"\bgit\s+" + _GO + r"(checkout|restore)\s+(--\s+)?\.(?:\s|$)"),
     "Mass discard of working-tree changes is irreversible.",
     "Discard specific files, or `git stash` to keep them recoverable."),
]


def deny(reason: str) -> None:
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, sys.stdout)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        return 0

    if data.get("tool_name", "") != "Bash":
        return 0

    cmd = (data.get("tool_input", {}) or {}).get("command", "") or ""
    for pat, reason, alt in GIT_DENY:
        if pat.search(cmd):
            deny(f"Blocked by git-guardrails: {reason} {alt} "
                 f"(To override, run it yourself in a terminal outside Claude Code.)")
            return 0
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)  # fail open
