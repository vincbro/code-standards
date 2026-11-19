# TypeScript review

The procedure for reviewing TypeScript. The `review` skill sends every `*.ts`, `*.tsx`, `package.json`, `tsconfig.json` and ESLint config file here. You check the code against [STYLE.md](STYLE.md), the way a careful maintainer would. `tsc`, ESLint and the tests already enforce everything mechanical. Your job is the rules that need judgment. How a screen looks is not covered here: a project that has UI rules names their review in `STANDARDS.local.md`.

**You never edit code.** When the `review` skill invoked you, return the findings and the rule checklist and **do not ask** what to implement. When a person invoked you directly, end by asking (step 7).

## 1. Load the rules, every time

Read in full before looking at any code:

1. `code-standards/typescript/STYLE.md`: every rule has an id (`T-…`), a reason and an *Enforced* line.
2. `STANDARDS.local.md` at the repo root, if it exists: the project's gate, its extra rules and overrides. Where it disagrees with `STYLE.md`, it wins. Check the project's own rules in the same pass.

The file is the source of truth. Never invent a rule: something that looks wrong but no rule covers goes under "Not covered".

## 2. Scope

Use the scope and file list the caller passed, otherwise resolve the argument as `code-standards/skills/review/scope.md` says. State the scope at the top of the report. Report only on lines the change adds or modifies (whole codebase: group repeats).

## 3. Mechanical sweeps

The gate has run (or the `review` skill said it couldn't). Don't repeat what `tsc` and ESLint report. These greps find candidates, and you judge each:

```
grep -nE ":\s*any\b|as any|<any>|@ts-(ignore|expect-error)" <files>     # T-TYPES
grep -nE "\bas [A-Z][A-Za-z<>\[\]| ]+" <files>                          # T-TYPES: assertions
grep -nE "\w!\b[.;,)\]]" <files>                                        # T-TYPES: non-null !
grep -nE "JSON\.parse|localStorage|sessionStorage" <files>              # T-BOUNDARY, T-STORAGE
grep -nE "catch\s*(\(\w*\))?\s*\{\s*\}|catch.*\{\s*//" <files>          # T-ERRORS: swallowed
grep -nE "useEffect|useLayoutEffect" <files>                            # T-EFFECTS
grep -nE "console\.(log|warn|error|debug)" <files>                      # T-NO-NOISE
grep -nE "<div[^>]*onClick" <files>                                     # T-A11Y
```

## 4. Check every rule

Walk `STYLE.md` top to bottom. For every `T-…` rule, including the tool-enforced ones (a cast or `@ts-` comment defeats `tsc`), check the code in scope against the rule's text as written, not against memory. Record one result per rule: **pass**, **finding**, or **n/a**. The ones that need the most judgment:

- **Correctness first:** `T-BOUNDARY`, `T-STORAGE`, `T-ERRORS`, and any project rule about exact values or mirrored types.
- **Types:** `T-TYPES`, `T-NARROW`, `T-UNIONS` (optional-field bags that should be unions), `T-EXHAUSTIVE` (a `Partial` or `string`-keyed map over a union, a `default` that swallows new cases), `T-READONLY`.
- **State and effects:** `T-STATE`, `T-EFFECTS`, `T-REACT`. For each `useState` or `useRef` in a component a user can leave and return to, ask whether they would be annoyed to lose it.
- **Structure:** `T-PURE` (rules inline in a component), `T-FLAT`, `T-SIZE`, `T-MODULES`, `T-HANDLERS`.
- **Names and comments:** `T-NAMES`, `T-NAMES-BOOLS`, `T-COMMENTS`, `T-DOCS`. Sweep every comment in scope, not a sample.
- **Tests:** `T-TESTS`: changed logic has a test that fails without the change; a bug fix has its failing test.

## 5. Verify every finding

Re-open the file at the line and confirm the code is as described. Quote the exact sentence of `STYLE.md` it breaks; if you can't, it isn't a violation. For a logic finding, give the input or sequence that goes wrong. "Could be better" with no cost is not a finding. Code you just wrote is reviewed like anyone else's.

## 6. Report

One-line verdict. Numbered findings, correctness first, then types, effects and state, then structure, tests and names, comments last:

```
src/Next.tsx:233  T-EFFECTS
  `started` lives in a ref that is never reset when `item` changes.
  → key the hook by `item`, or reset the refs in one place.
```

Then: the rule checklist (every `T-…` id and the project's own ids), the gate result or that you couldn't run it, comments checked, and **Not covered** questions.

## 7. Ask (only when a person invoked you directly)

Ask what to implement: **all**, **some** by number, or **none**. Then stop and wait.
