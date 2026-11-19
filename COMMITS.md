# Commits

How commit messages are written, in any language. The rule has an ID (`S-COMMITS`) so a review can cite it.

## S-COMMITS: `area: lowercase imperative summary`

```
view: scroll by row instead of by line

Scrolling moved whole lines, so a line that wrapped past the bottom of
the screen could never be scrolled through. Scroll one row at a time.
```

- The first line is `area: summary`, where `area` is the module or topic (for example a module name, `ci`, `deps`, `docs` or `style`). The summary is lowercase except for code and proper nouns, starts with an imperative verb, has no trailing period, and is at most 72 characters (ideally 50).
- A blank line follows, then a body saying **why**: what was wrong or missing, and the idea of the fix. Use prose, not a list of files. Wrap at 72 characters. Leave the body out when the summary says it all.

*Why:* `git log --oneline` then scans by area, and the body records the reasoning the diff can't show.

*Enforced:* hook, when the project installs one (see `STANDARDS.local.md`). Otherwise review.
