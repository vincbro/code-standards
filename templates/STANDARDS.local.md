# Project standards

What is specific to this project. The shared rules are in `code-standards/`. Where this file disagrees with them, this file wins. Leave out any section that doesn't apply.

## Commands

- **Gate** (must pass before any change is done):
- **Full gate** (the gate with every property test run for many cases, for after touching a stateful type; leave out if there is none):
- **Commit-message check** (takes a message file; leave out if there is none):
- **Benchmarks** (for P-MEASURE):

## Hot paths

The code that runs per event or per frame, by name. `PERFORMANCE.md` rules about hot paths apply to these and what they call.

-

## Known performance opportunities

Measured, not yet changed. A review doesn't repeat these. It reports one only if a change makes it worse, or notes when a change fixes one.

| Where | What | Numbers |
|---|---|---|
| | | |

## Overrides

Rules from `code-standards/` this project bends, each with the reason.

-
