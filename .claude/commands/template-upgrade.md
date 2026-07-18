---
description: Upgrade this repo's .claude/ configuration to the latest agentic-repo-template release, preserving your customizations.
---

# /template-upgrade

Upgrade the current repo to the latest [agentic-repo-template](https://github.com/groundnuty/agentic-repo-template) release. Reads `.claude/.template-version` for the profile and flags, so nothing needs to be specified. Regenerates the template-owned config (settings.json, skills/agents/hooks/templates/commands, profile rules), preserves your files, backs everything up first.

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

   This backs up `.claude/` → `.claude.pre-upgrade-<oldversion>/` (gitignored), regenerates the template-owned config for this repo's stamped profile + flags, and preserves `settings.local.json`, `rules/project-conventions.md`, `.claude/CLAUDE.md`, `audit.log`, and `session-reports/`. The stamp is bumped to the new version.

3. **Reconcile the settings.json report.** If the upgrader printed a "settings.json entries in your current config but not in the new template output" section, each listed entry is **either** a customization you added **or** an entry the new version intentionally removed. Decide per entry using the CHANGELOG delta the upgrader printed:
   - If an entry was **removed by the template** (mentioned in the CHANGELOG, e.g. a deprecated `Write(path)` deny) — leave it dropped.
   - If an entry is **your customization** (not in the CHANGELOG) — move it into `.claude/settings.local.json` (the gitignored escape hatch, preserved across future upgrades), not back into `settings.json`.

   When in doubt, show the user the entry and the backup at `.claude.pre-upgrade-<oldversion>/settings.json`, and ask.

4. **Verify + report.** Confirm `.claude/settings.json` still parses (`jq -e . .claude/settings.json`), summarize the version jump and what you relocated, and remind the user the backup directory can be deleted once they're satisfied. Do not commit automatically unless the user asks — let them review the diff first.

## Notes

- Works on any repo initialized from the template (v0.1.9+, which is when the stamp was introduced). Repos without a `.claude/.template-version` can't be auto-upgraded — run `/template-check` for how to create the stamp.
- `--ref vX.Y.Z` upgrades to a specific version instead of latest.
- The upgrade **never** merges old `settings.json` into new (a union merge would re-add entries the template deliberately removed). It regenerates fresh; your overrides live in `settings.local.json`.
