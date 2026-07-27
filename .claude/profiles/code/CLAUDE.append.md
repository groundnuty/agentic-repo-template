<!-- Profile: code -->

## Profile: code

Code-centric work — writing and refactoring code. Language-agnostic baseline.

**At first init,** run `/run-skill-generator` to capture this repo's app-launch recipe as a committed skill, and `/verify` to capture its verification recipe. Both beat re-describing the same commands to every new session.

**Toolchain:** this profile assumes [devbox](https://www.jetify.com/devbox) for toolchain management. Using Nix flakes directly, or another manager? Adapt `.claude/rules/devbox-usage.md` — the rest of the profile does not depend on it.

**Language-specific reviewers are opt-in, not shipped.** Run `/configure-ecc` from the [`everything-claude-code`](https://github.com/affaan-m/everything-claude-code) plugin and pick only what your language needs; the full bundle (183 skills, 48 agents) is too heavy to enable by default.
