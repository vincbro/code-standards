# Setup (for agents)

You are installing the code standards into a project. This repo is mounted in the project as `code-standards/`. Follow these steps, and show the person what you changed.

## 1. Check the mount

`code-standards/` must exist at the project root and be non-empty. If it is empty, run `git submodule update --init code-standards`. If it doesn't exist, run `git submodule add git@github.com:vincbro/code-standards.git code-standards` (the path must be `code-standards`, because the skills refer to it).

## 2. Install the skills

Copy these two files into the skills folder of the agent you are, **keeping the folder names**:

| From | To (Claude Code) |
|---|---|
| `code-standards/skills/review/SKILL.md` | `.claude/skills/review/SKILL.md` |
| `code-standards/skills/commit/SKILL.md` | `.claude/skills/commit/SKILL.md` |

For another agent, use its equivalent folder (for example `.codex/skills/`) and adapt only the frontmatter if its format differs. Don't change the body, and don't copy `scope.md` or any rule file: the skills read those from `code-standards/` in place, so they stay current when the submodule moves.

Then write the marker `.code-standards-version` next to the installed skills (for Claude Code, `.claude/skills/.code-standards-version`) containing the output of:

```
git -C code-standards rev-parse HEAD:skills
```

That is the id of the skills folder's content. It only changes when a skill changes, not on every rules update.

## 3. Create the local file

If `STANDARDS.local.md` doesn't exist at the project root, copy `code-standards/templates/STANDARDS.local.md` there and fill it in from the project: its gate command, its commit-message check, its hot paths. Ask the person for anything you can't find in the repo. Leave a section out rather than guessing.

## 4. Point `AGENTS.md` at it

Add this to the project's `AGENTS.md` (create it if there is none), once:

```
## Code standards

Rules live in `code-standards/` (a submodule). Read `code-standards/<language>/` before writing or reviewing code in that language, and `STANDARDS.local.md` for what is specific to this project.
Use the `review` skill to review a change and the `commit` skill to commit. Run `review` on your own changes before you call any code change done.
```

## 5. Staying current

`review` checks for a newer `code-standards` at the start of every run and offers to update. To check or update by hand, follow `code-standards/UPDATE.md`. The installed skills are stale when the marker differs from `git -C code-standards rev-parse HEAD:skills`: redo step 2 and update the marker.
