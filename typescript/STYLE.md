# TypeScript style

How TypeScript is written, for React and Vite projects run with bun. Most of it is enforced: the project's check fails on anything `tsc` and ESLint can catch. The rest is checked in review, by people or by the review skill (`typescript/REVIEW.md`). Every rule has an ID (`T-…`) so a review can cite it. Commit messages are in [COMMITS.md](../COMMITS.md). The Rust counterpart is [rust/STYLE.md](../rust/STYLE.md).

Each rule says what to do, **why**, and what enforces it:

- `tsc`: `tsc --noEmit` with `strict`, `noUncheckedIndexedAccess`, `noUnusedLocals`, `noUnusedParameters`, `noFallthroughCasesInSwitch`, `noImplicitReturns`, `noImplicitOverride`
- `lint`: ESLint with typescript-eslint, where each rule names the `T-…` id it serves
- `test`: `bun test`
- `build`: the bundler build
- `review`: nothing automatic. Reviewers and the review skill check it.

The commands that run these are the project's own, listed in its `STANDARDS.local.md`. A project adds its own rules there too (its own ids, never `T-…`).

A rule a tool enforces is not up for debate: fix the code. A rule marked `review` is where judgment comes in: a reviewer flags it with the ID, and the author fixes it or says why this case is the exception.

**Rule ids.** T-TYPES, T-NARROW, T-UNIONS, T-TYPE-ALIASES, T-EXHAUSTIVE, T-READONLY, T-BOUNDARY, T-STORAGE, T-ERRORS, T-PURE, T-STATE, T-EFFECTS, T-REACT, T-HANDLERS, T-FLAT, T-SIZE, T-MODULES, T-IMPORTS, T-NAMES, T-NAMES-BOOLS, T-COMMENTS, T-DOCS, T-A11Y, T-DEPS, T-NO-NOISE, T-TESTS, T-PERF.

---

## Types

### T-TYPES: The types tell the truth

No `any`, no `@ts-ignore`, no `@ts-expect-error` without a one-line reason, and no `as` to silence the compiler. A non-null `!` or an `as` is allowed only when the line before it proves it, and a reader can see why. Use `unknown` for what you don't know yet and narrow it.

*Why:* the compiler is the cheapest reviewer. An assertion turns it off at that spot, and the bug appears later, somewhere else, as a wrong value on screen.

*Enforced:* tsc (`strict`) and lint (`no-explicit-any`, `no-non-null-assertion`, `ban-ts-comment`, `no-unnecessary-type-assertion`). Review catches the `as` that lint allows.

### T-NARROW: Narrow, don't assert; handle the missing case

An array index or a `Map.get` can be missing (`noUncheckedIndexedAccess`). Handle it (`if (!x) return`, `?? fallback` with a fallback that is correct, not a placeholder) instead of `!`. Narrow with `typeof`, `in`, `Array.isArray` or a discriminant, not a cast.

*Why:* a backend can return an empty list, an index can be out of range, a stored value can be old. The unhappy case is where the user sees a blank screen or a wrong number.

*Enforced:* tsc (`noUncheckedIndexedAccess`). Review checks the fallback is correct.

### T-UNIONS: Model states as a discriminated union

Values that are valid only together are one union with a `kind` (or `status`) field, not a bag of optional fields:

```ts
type Task =
  | { kind: "learn"; lesson: string; reason: string }
  | { kind: "practice"; item: string; reason: string }
  | { kind: "done"; reason: string };
```

Don't use `enum`. Use a string-literal union.

*Why:* an optional-field bag allows combinations that mean nothing, and every reader has to know which. A union makes the impossible state unwritable, and `switch` narrows each case.

*Enforced:* review.

### T-TYPE-ALIASES: `type`, not `interface`; named exports only

Declare shapes with `type`. No `interface`, no `enum`, no `namespace`, no `default export`. Derive a type from a value (`typeof`, `as const`, `satisfies`) instead of writing it twice.

*Why:* one way to declare means one thing to learn. Named exports are greppable and rename safely. A `const` object with `as const` gives the union and the runtime list from one source.

*Enforced:* lint (`consistent-type-definitions`, and `no-restricted-syntax` for `enum` and `export default`; `vite.config.ts` is exempt because Vite requires a default export).

### T-EXHAUSTIVE: A `switch` or map over a union is exhaustive

A `switch` on a union ends in a `never` check or has no `default`; a lookup table over a union is `Record<Union, …>`, never `Partial`, `string`-keyed or `Record<string, …>`.

```ts
const TONE: Record<Check["status"], Tone> = { ok: …, failed: …, /* every status */ };
```

*Why:* when a variant is added to a union (including one mirrored from another language), `tsc` must fail on every place that has to learn about it.

*Enforced:* lint (`switch-exhaustiveness-check`), and tsc when the types are exact (`noImplicitReturns`, `noFallthroughCasesInSwitch`). Review catches widened maps and a `default` that swallows new cases.

### T-READONLY: Data that doesn't change is `readonly`

Props, loaded content, server snapshots and module constants are `readonly` (`readonly string[]`, `ReadonlySet`, `as const`). Nothing mutates a snapshot, a loaded record or a prop; build a new value.

*Why:* React and memoisation assume values don't change under them. A hidden mutation shows a stale or wrong line, and it is hard to find.

*Enforced:* review.

---

## Boundaries and errors




### T-BOUNDARY: Untrusted input is parsed, not cast

Data from `localStorage`, an opened file, `JSON.parse`, parsed content and any server or worker response is typed `unknown` and validated at the edge, with a fallback for a missing or old shape. After the edge the types can be trusted.

*Why:* a stored shape from last week's version, or a file the user edited, will not match the type you wrote today. A cast turns that into a crash deep inside a component.

*Enforced:* review.

### T-STORAGE: Storage is wrapped, namespaced and tolerant

Reads and writes go through one wrapper module (try/catch: private windows, blocked storage, quota). No direct `localStorage` elsewhere. Keys share one project prefix. A reader accepts the previous shape. A destructive reset is an explicit action, never a side effect.

*Why:* storage can throw or be empty, and the user's progress and work live there.

*Enforced:* review (`grep -n "localStorage\|sessionStorage"`).

### T-ERRORS: No silent failure

No empty `catch`. A failure the user can cause becomes a message in the view; one they can't becomes a visible "can't tell" state or a logged bug note, never a blank screen. A promise is awaited, or `void`-ed on purpose. While a backend or worker loads or has failed, the view says so. An `Error` message is a lowercase fragment (as in S-ERROR-TEXT in `rust/STYLE.md`).

*Why:* an honest "can't tell" is better than a blank pane or a stale result.

*Enforced:* lint (`no-floating-promises`, `no-misused-promises`, `no-empty`, `prefer-promise-reject-errors`). Review checks the rest.

---

## Structure

### T-PURE: Logic lives outside components, with a test

Anything with a rule in it (choosing what to show, grading, scheduling, layout maths, text processing, parsing) is a plain `.ts` module with a test in `web/tests`. A component is layout and wiring.

*Why:* a pure function is tested in milliseconds with no DOM. Logic inside a component can only be tested by clicking.

*Enforced:* review.

### T-STATE: State has one owner and no copies

State that can be computed from other state is computed (`useMemo` or a plain expression), not stored. State two views need lives above both, or in a shared view-state store. State that is meaningful to the user (a step reached, a typed answer, a filter) is not a bare `useState` in a view they can leave. No `useRef` used as a hidden store for something that must re-render.

*Why:* two copies disagree, and the user sees the stale one. Lost state costs them their place.

*Enforced:* review.

### T-EFFECTS: Effects are for the outside world

`useEffect` is for subscriptions, timers, the DOM and storage, not for deriving state from props. Every subscription and timer is cleaned up. Dependency arrays are complete: no lint suppression. No chain where one effect sets state another effect reads.

*Why:* effect chains run in a different order than they read, and cause flicker, loops and stale values.

*Enforced:* lint (`react-hooks/exhaustive-deps`). Review checks the rest.

### T-REACT: React correctness

Keys are stable and meaningful, never the array index of a list that reorders or inserts. A key that resets a component's state is a decision: say why in a comment. No hook after an early return. No state update during render. Use a functional update (`setX(x => …)`) when the new value depends on the old.

*Why:* these are the bugs that appear only after the second click.

*Enforced:* lint (`react-hooks/rules-of-hooks`). Review checks the rest.

### T-HANDLERS: Handlers do one thing and a name says which

A prop callback is `onX`; the function that implements it is `handleX` or a verb (`addProblem`). A handler longer than a few lines calls a named function. No inline logic in JSX beyond a condition and a call.

*Why:* JSX is for reading structure. Logic buried in it can't be found, named or tested.

*Enforced:* review.

### T-FLAT: Keep code flat

No more than four levels of nesting. Return early, extract a named function, `switch` on a union instead of an `if` ladder, and give a `.map` callback with branches its own component or function.

*Why:* the same as S-FLAT in `rust/STYLE.md`: every level is one more condition to hold in your head.

*Enforced:* lint (`max-depth` of 4). Review flags code that passes only by being awkward.

### T-SIZE: Files and functions stay readable

A component over about 150 lines, a function over about 60, or a file over about 400 needs a reason. Flag what makes it hard to follow, not the count alone. One idea per file. Split by what changes together, not by kind (not a `components/` of 40 unrelated files).

*Enforced:* lint, partly (`max-lines` fails above 800). Review judges the rest.

### T-MODULES: One way in, no cycles

Modules form a layer (types and data at the bottom, memory and logic above, views at the top). A lower module never imports a view. No import cycles. A view imports from a few places, not from every module.

*Why:* cycles make load order matter and break the bundler in ways that show up only in production.

*Enforced:* build catches some. Review checks the direction.

### T-IMPORTS: Imports are grouped and typed

Group: external packages, then `@/…` (shared `components/` and `lib/`), then sibling files (`./…`). Type-only imports use `import type`. No import that is only used for a side effect, except the CSS and the preload.

*Enforced:* tsc (`noUnusedLocals`) and lint (`consistent-type-imports`). Review for grouping.

---

## Names, comments, docs

### T-NAMES: A name says what the thing is

No abbreviated type names (`Expression`, not `Expr`; S-NAMES-TYPES in `rust/STYLE.md` applies here too). Elsewhere only the abbreviations everyone knows: `id`, `i`/`j`/`n`, `props`, `ref`. A value is named for what it holds, not how it is computed. Component names are nouns; functions are verbs; hooks start with `use`.

*Enforced:* review.

### T-NAMES-BOOLS: A boolean reads as a question

`isOpen`, `hasHint`, `canSubmit`, not `open`, `hint`, `submit`. A boolean prop that has two flags is two props or a union (`mode: "submit" | "free"`), not `a` and `b`.

*Why:* at the call site you only see `true`.

*Enforced:* review.

### T-COMMENTS: `//` comments say why

A `//` comment carries the reasoning the code can't show. It never restates the next line. No commented-out code.

*Enforced:* review.

### T-DOCS: `/** */` adds what the name and type can't say

A `/** */` doc comment goes on a module-level function, component or type when it says what it is for, what it promises, or what it keeps true (an invariant, a unit such as "UTF-16 code units", the reason a key resets state). Don't document what the name and type already say. When a doc is explaining how confusing code works, the fix is clearer code. Docs are full sentences ending with a period.

*Why:* docs that exist only where they add insight get read.

*Enforced:* review.

---

## Accessibility and dependencies

### T-A11Y: Real elements, keyboard-complete

An interactive thing is a `<button>` or an `<a href>`, never a `div` with `onClick`. A click target also works with the keyboard. An icon-only control has an `aria-label`. A form control has a label. Visible focus is never removed. 

*Why:* it is the cheapest accessibility there is, and it makes links that open in a new tab work.

*Enforced:* review (`grep -nE "<div[^>]*onClick"`).

### T-DEPS: A dependency is earned

A new package has a reason and is used. `bun`, not npm or node. No second library for something an existing one does. Prefer a few lines of code to a package for something small.

*Enforced:* review. (`bun.lock` is committed with `package.json`.)

### T-NO-NOISE: No leftovers

No `console.*`, commented-out code, dead exports or unused files. A `TODO` names the issue or item that tracks it.

*Enforced:* tsc for unused locals, lint for `console` and `debugger`; review for the rest.

---

## Tests and speed

### T-TESTS: Behaviour has a test, written first for a bug

Logic added or changed in a `.ts` module has a `bun test` that fails without the change. For a bug, write the failing test from the input you saw, then fix it. Test names say the behaviour. A test drives the logic with real data, not mocks of it. A UI behaviour that matters (state kept after navigating, a preview appears) gets a render test.

*Why:* the same as Rust: end-to-end tests catch what a user hits.

*Enforced:* test (it runs); review checks that the change comes with one.

### T-PERF: Keep the per-input path light

Code that runs per keystroke or per frame doesn't repeat work it already has: derive from existing data with `useMemo`, and don't create objects or functions in a render that a memoised child depends on. Don't optimise by feel: when a change is made for speed, say what was measured (the same as P-MEASURE in `rust/PERFORMANCE.md`).

*Why:* any lag between a key and the response is felt.

*Enforced:* review.
