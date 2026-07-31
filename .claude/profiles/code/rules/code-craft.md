# Code craft

Preferences that are not defaults. Everything a competent model already does by
habit is deliberately absent — these are the calls that differ, or that are easy
to skip under time pressure.

## Shape

- Return new values rather than mutating arguments in place. When mutation is
  the point (a buffer, a hot loop), say so in a comment.
- Extract rather than let a file grow past ~400 lines, or a function past ~50.
  Deep nesting is the earlier signal: past four levels, restructure.

## Failure

- Handle errors explicitly at the level that can do something about them. Never
  silently swallow one — a caught-and-ignored exception is a bug with a hiding
  place.
- Validate at the boundary: user input, API responses, file contents, anything
  crossing into your code. Fail fast, with a message that names what was wrong.

## Secrets

- Never hardcode a secret. Environment variables or a secret manager, and check
  the required ones are present at startup rather than at first use.
