# code-standards

One place for the coding rules and the agent skills that enforce them, shared by every project through a git submodule so they can't drift apart.

## Layout

```
code-standards/
  SETUP.md                   # agent-facing: how to install into a project
  UPDATE.md                  # agent-facing: check for and apply updates
  COMMITS.md                 # commit message format, any language
  scripts/check-update.sh    # read-only: is the project behind upstream?
  rust/
    REVIEW.md                # how to review Rust: style + performance
    STYLE.md                 # S-… rules
    PERFORMANCE.md           # P-… rules
  typescript/
    REVIEW.md                # how to review TypeScript
    STYLE.md                 # T-… rules
  skills/
    review/SKILL.md          # static router: files → language REVIEW.md
    review/scope.md          # what a review argument means
    commit/SKILL.md          # review, fix, split, commit
  templates/
    STANDARDS.local.md       # per-project facts and overrides
```

## Use in a project

```
git submodule add git@github.com:vincbro/code-standards.git code-standards
```

Then ask your agent to follow `code-standards/SETUP.md`. It copies the two skills into its own skills folder (`.claude/skills/`, `.codex/skills/`, …). The copies hold no rules: they point at `code-standards/`, so bumping the submodule updates the rules everywhere. Only a change to a skill itself needs a re-copy. Every `review` checks for a newer version and offers to update (`UPDATE.md`); it never applies one on its own.

Project-specific facts (the gate command, hot paths, known problems, overrides) live in the project's `STANDARDS.local.md`, never in this repo.

## Add a language

1. Make `<language>/` with its rule files and a `REVIEW.md` that says how to check them and what to report. Follow `rust/REVIEW.md`.
2. Add one row to the table in `skills/review/SKILL.md`.

The router holds no rules, so nothing else changes.

## Rules for the rules

- Every rule has a permanent id (`S-…`, `P-…`), a reason and an *Enforced* line. Never renumber or reuse an id: reviews cite them.
- Nothing project-specific goes in here. Examples that name a real project's types are fine as illustrations.
