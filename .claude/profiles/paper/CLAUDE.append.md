<!-- Profile: paper -->

## Profile: paper

Academic manuscript work — literature review, prose polishing, structured peer review. Format-agnostic (LaTeX, Markdown, Word, Google Docs). Layers on `research`; layer `paper-latex` on top when the manuscript compiles with LaTeX. Scholar Gateway setup and its journals-only caveat carry over from the `research` profile.

**The paper capability ships as a plugin,** `agentic-paper@agentic-plugins`, not as files under `.claude/`. Its skills and agents are namespaced: `/agentic-paper:review-paper`, `/agentic-paper:verify-claims`, `/agentic-paper:proofread`, `/agentic-paper:seven-pass-review`, `/agentic-paper:respond-to-referees`, `/agentic-paper:audit-reproducibility`, `/agentic-paper:analyze-paper`, `/agentic-paper:humanizer`, and the agents `agentic-paper:editor` / `:domain-referee` / `:methods-referee` / `:proofreader` / `:claim-verifier`. Update it with `claude plugin update agentic-paper@agentic-plugins`. If a slash command does not resolve, the plugin is not installed for this repo — run `claude plugin marketplace add groundnuty/agentic-plugins --scope project` then `claude plugin install agentic-paper@agentic-plugins --scope project`, in this directory.

**Auto-memory does not reach subagents** (except forks). The editor, referee, and proofreader agents carry `memory: project` so they can see it; `agentic-paper:claim-verifier` deliberately does **not**, and must stay that way — a verifier that has read the draft is not an independent check. Anything a subagent needs goes in its prompt or in a committed file.

**Before `/agentic-paper:review-paper --peer`,** fill in `.claude/templates/journal-profile-template.md` for your target venue. Left blank, the referees run on generic norms.

**Opt-in hooks** — reference them from `.claude/settings.local.json` to activate: `hooks/notify.sh` (desktop notification on session events), `hooks/log-reminder.py` (stop-hook reminder to update the session log).
