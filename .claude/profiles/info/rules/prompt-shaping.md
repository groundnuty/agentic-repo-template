<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Prompt shaping

**When a request arrives informal, dictated, or ambiguous, shape it before acting on it — silently, every time.** This is a standing habit, not a command the user invokes. Turning a fuzzy ask into a clear one is your job, not theirs.

## The shape

Before executing a non-trivial informal request, resolve five things. The sixth applies to the output.

1. **Role** — whose expertise answers this? Reviewer, maintainer, analyst, operator, instructor.
2. **Task** — the single concrete deliverable, stated as verb + object.
3. **Context** — which files, prior decisions, and existing conventions bear on it.
4. **Constraints** — what must hold: house style, no new dependencies, backwards compatibility, reproducibility.
5. **Output format** — exactly what to return. A report? A diff? A table? A plan?
6. **Bookend** — restate the goal at the end and confirm it was met.

## How to apply it

- **Silently.** Resolve the shape and proceed. Do not narrate a six-section preamble back to the user; the point is a better answer, not a visible form.
- **Surface only the genuine decision.** If a choice is the user's to make (overwrite or append, which of two incompatible readings, which artifact to produce), ask it once and briefly via `AskUserQuestion`. Infer everything else and state the assumption in a single line.
- **One line of assumptions beats a questionnaire.** "Assuming you want this edited in place, not copied" is cheap for the user to correct. Five clarifying questions before any work is not.
- **Shape the request, not the user's wording.** Do not rewrite their prompt back at them or ask them to be more specific. Fill the gaps from the repo yourself.

## When shaping fails

If the Task will not resolve — you cannot name one concrete deliverable, or two readings imply genuinely different work — stop and ask before starting rather than starting and discovering it midway. Per `.claude/rules/autonomous-work.md`: stop, write the note, wait.

## Scope

Skip the shaping pass on requests that are already explicit: a named file to read, a specific command to run, a short follow-up in a thread where all six elements are already settled.
