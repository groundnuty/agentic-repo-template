# PR discipline

## Commit message format

```
<type>: <description>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`.

## Message body

- **Why, not what.** The diff shows what changed. The message explains why.
- **Reference spec / plan sections when applicable** — e.g., `(per Task 5 in docs/plans/<plan>)`.
- **Keep the attribution.** Leave the `Co-Authored-By` trailer Claude Code adds to commits, and its note on pull requests: they record which changes an agent wrote, so the history shows provenance.

## Making the commit

Commits and tags here may be signed, and signing works only for a plain command: make each commit with a single `git commit` (optionally `git add … && git commit …`) as its own Bash call, with the message as one or more `-m` options — one per paragraph, the attribution trailer as the last. Don't build the message with a heredoc or `$(…)`, and don't use `-C <dir>` or chain other commands after it; those shapes fail with "gpg failed to sign".

## When to open a PR

- Feature complete and verified — all tests pass, all lints clean.
- Logical unit of work — don't bundle unrelated changes.
- PR title under 70 characters; use the body for detail.

## PR body structure

```markdown
## Summary
<1-3 bullets>

## Test plan
- [ ] <manual or automated check>
- [ ] <another>
```

## Never

- `git push --force` or any variant (blocked by the deny list).
- `git commit --no-verify` (blocked).
- Merging without the project's checks passing.
