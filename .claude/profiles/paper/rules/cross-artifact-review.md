<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->

# Cross-artifact review

When `/agentic-paper:review-paper` runs on a manuscript that references analysis scripts, the review MUST also review those scripts and run `/agentic-paper:audit-reproducibility` — the protocol lives in the `agentic-paper:review-paper` skill. This fires automatically; `--no-cross-artifact` opts out.
