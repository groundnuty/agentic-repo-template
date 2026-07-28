<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Post-flight verification

Skills that produce documents with factual claims MUST run the `/agentic-paper:verify-claims` post-flight before returning: extract the claims, verify them in a fresh context that never saw the draft (Chain-of-Verification), then report by tier. The protocol lives in the `agentic-paper:verify-claims` skill.
