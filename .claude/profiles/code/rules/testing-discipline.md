# Testing discipline

**Tests are the definition of done for code work.** Untested new behavior is not finished behavior, whatever the diff looks like.

Write tests with the change — before it when writing the test clarifies the design, which is most of the time for a new interface or a reported bug. Run the project's real suite before claiming done, and read the output; a green summary you did not look at proves nothing.

Mirror the source tree, one behavior per test, no dependence on test order, shared state, the network, or a particular machine. A flaky test is a real bug: investigate it, don't rerun it. Never comment out a failing test, and never patch the runner so a failure stops being reported.

`/verify` captures a repo-specific verification recipe; `/run-skill-generator` commits an app-launch skill. Use them instead of re-describing verification every session.
