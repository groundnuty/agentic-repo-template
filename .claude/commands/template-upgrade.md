---
description: Upgrade this repo's .claude/ configuration to the latest agentic-repo-template release, preserving your customizations.
---

# /template-upgrade

Upgrade the current repo to the latest [agentic-repo-template](https://github.com/groundnuty/agentic-repo-template) release. Reads `.claude/.template-version` for the profile and flags, so nothing needs to be specified. Overlays template-owned files in place (settings.json, skills/agents/hooks/templates/commands, profile rules) — **custom files you added under `.claude/` are never touched**, `.claude/CLAUDE.md` and `rules/project-conventions.md` are never overwritten (the fresh template CLAUDE.md lands in the backup as `CLAUDE.md.template-new` for manual merge), and everything is backed up first.

## What to do

1. **Preview first.** Fetch the upgrader and run a dry-run so you can see the version jump, the CHANGELOG delta, and any custom `settings.json` entries before anything changes:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/groundnuty/agentic-repo-template/main/upgrade.sh -o /tmp/arp-upgrade.sh
   bash /tmp/arp-upgrade.sh --dry-run
   ```

   If it reports "Already up to date," stop — there's nothing to do.

2. **Apply the upgrade:**

   ```bash
   bash /tmp/arp-upgrade.sh
   ```

   This backs up `.claude/` → `.claude.pre-upgrade-<oldversion>/` (gitignored), then **overlays** template-owned files in place for this repo's stamped profile + flags. Never overwritten: `.claude/CLAUDE.md` (the fresh template version with profile appends is saved to the backup as `CLAUDE.md.template-new` for manual merge), `rules/project-conventions.md`, and **any custom file you added** (rules, scripts, hooks, `.macf/`, …). Deliberately-removed template files are deleted per `removed-files.txt`. Root `.example` files regenerate; your live `.mcp.json` is never touched. The stamp is bumped.

3. **Reconcile the settings.json report.** If the upgrader printed a "settings.json entries in your current config but not in the new template output" section, each listed entry is **either** a customization you added **or** an entry the new version intentionally removed. Decide per entry using the CHANGELOG delta the upgrader printed:
   - If an entry was **removed by the template** (mentioned in the CHANGELOG, e.g. a deprecated `Write(path)` deny) — leave it dropped.
   - The report is **partitioned** (v0.2.0+): entries labeled *REMOVED BY THE NEW TEMPLATE* must **not** be restored. For an entry labeled **your customization** — move it into `.claude/settings.local.json` (the gitignored escape hatch, preserved across future upgrades), not back into `settings.json`.

   When in doubt, show the user the entry and the backup at `.claude.pre-upgrade-<oldversion>/settings.json`, and ask.

4. **Check the capability-plugin step (paper tiers, v0.3+).** After the scaffold summary the upgrader installs and verifies this repo's declared plugins at **project scope**, then — only if that verify is green — deletes the file copies the plugin now supersedes (the backup keeps them). If it printed `PLUGIN STEP FAILED` and **exited 4**, the scaffold upgrade itself is complete and safe, but the plugin's skills and agents are **absent** and Claude Code will not say so. Run the two commands the diagnostic names, in this directory, then re-run the upgrader — it re-verifies even when the scaffold is already up to date.

5. **Verify + report.** Confirm `.claude/settings.json` still parses (`jq -e . .claude/settings.json`), summarize the version jump and what you relocated, and remind the user the backup directory can be deleted once they're satisfied. Do not commit automatically unless the user asks — let them review the diff first.

## Notes

- Works on any repo initialized from the template (v0.1.9+, which is when the stamp was introduced). Repos without a `.claude/.template-version` can't be auto-upgraded — run `/template-check` for how to create the stamp.
- `--ref vX.Y.Z` upgrades to a specific version instead of latest.
- The upgrade **never** merges old `settings.json` into new (a union merge would re-add entries the template deliberately removed). It regenerates fresh; your overrides live in `settings.local.json`.
