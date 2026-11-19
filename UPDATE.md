# Update (for agents)

How a project moves to the latest code standards. The rules live in the `code-standards/` submodule, so an update is a new pin plus, rarely, a re-copy of the skills.

## Check (read-only)

From the project root:

```
sh code-standards/scripts/check-update.sh
```

| Output | Meaning |
|---|---|
| `current` | Up to date. Say nothing. |
| `offline` | Couldn't reach upstream. Say nothing, and don't retry in the same task. |
| `update <n> skills-same <sha>` | `<n>` commits behind; rules changed, installed skills are fine. |
| `update <n> skills-changed <sha>` | `<n>` commits behind; the installed skills are stale too (or have no marker). |

The check only fetches. It never changes the pin, the working tree or the skills.

## Apply (only after the person agrees)

1. Show what's coming: `git -C code-standards log --oneline HEAD..FETCH_HEAD`.
2. Run `git submodule update --remote code-standards`.
3. If the check said `skills-changed`, redo step 2 of `SETUP.md` (copy the two skills, rewrite the marker).
4. Read the log from step 1 for new or changed rule ids and tell the person which, since the code under review may now violate them.
5. Leave the new pin (and any re-copied skills) uncommitted for the person, or commit them with the `commit` skill as `standards: update code-standards`. Don't push.

If the submodule has local changes or isn't on a detached pin, stop and report; don't force it.

## When to check

At the start of every `review` (step 0 of the skill). The review reports a pending update in one line and offers to apply it, but never applies it by itself, because it never edits anything.
