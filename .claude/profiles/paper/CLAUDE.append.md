<!-- Profile: paper -->

## Profile: paper

Academic manuscript work — literature review, prose polishing, structured peer review. Format-agnostic (LaTeX, Markdown, Word, Google Docs). Layers on `research`; layer `paper-latex` on top when the manuscript compiles with LaTeX. Scholar Gateway setup and its journals-only caveat carry over from the `research` profile.

**Refresh vendored skills** with `./.claude/refresh-skills.sh [name]` — it re-clones every `source: "git"` entry in `.claude/skills.manifest.json` at the pinned `ref`. Currently that is `humanizer`, pinned to `v2.9.1`.

**Auto-memory does not reach subagents** (except forks). The editor, referee, and proofreader agents carry `memory: project` so they can see it; `claim-verifier` deliberately does **not**, and must stay that way — a verifier that has read the draft is not an independent check. Anything a subagent needs goes in its prompt or in a committed file.

**Before `/review-paper --peer`,** fill in `.claude/templates/journal-profile-template.md` for your target venue. Left blank, the referees run on generic norms.

**Opt-in hooks** — reference them from `.claude/settings.local.json` to activate: `hooks/notify.sh` (desktop notification on session events), `hooks/log-reminder.py` (stop-hook reminder to update the session log).
