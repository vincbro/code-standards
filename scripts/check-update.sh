#!/bin/sh
# Read-only: is the project's code-standards submodule behind upstream?
# Run from the project root. Prints one line:
#   current
#   offline
#   update <n> <skills-changed|skills-same> <short-sha>
# Never changes the working tree, the submodule pin or the installed skills.

sub=code-standards
[ -e "$sub/.git" ] || { echo "offline"; exit 0; }

branch=$(git -C "$sub" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
branch=${branch:-main}

git -C "$sub" fetch --quiet origin "$branch" 2>/dev/null || { echo "offline"; exit 0; }

behind=$(git -C "$sub" rev-list --count HEAD..FETCH_HEAD 2>/dev/null || echo 0)
[ "$behind" -gt 0 ] || { echo "current"; exit 0; }

new=$(git -C "$sub" rev-parse FETCH_HEAD:skills)
installed=""
for m in .claude/skills/.code-standards-version .codex/skills/.code-standards-version; do
  [ -f "$m" ] && installed=$(cat "$m") && break
done

if [ "$installed" = "$new" ]; then s=skills-same; else s=skills-changed; fi
echo "update $behind $s $(git -C "$sub" rev-parse --short FETCH_HEAD)"
