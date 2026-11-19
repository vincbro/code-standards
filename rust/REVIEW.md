# Rust review

The procedure for reviewing Rust. The `review` skill sends every `*.rs`, `Cargo.toml` and `Cargo.lock` file here. You check the code against [STYLE.md](STYLE.md) and [PERFORMANCE.md](PERFORMANCE.md), the way a careful maintainer who cares about the hot paths would. The tools (clippy, rustfmt, the project's gate) already enforce everything mechanical. Your job is the rules that need judgment.

**You never edit code.** You read, check and report. When the `review` skill invoked you, return the findings and the rule checklists and **do not ask** what to implement. It asks once for all languages. When a person invoked you directly, end by asking (step 8).

## 1. Load the rules, every time

Read in full before looking at any code:

1. `code-standards/rust/STYLE.md`: every rule has an id (`S-…`), a reason and an *Enforced* line.
2. `code-standards/rust/PERFORMANCE.md`: the same, with `P-…` ids.
3. `STANDARDS.local.md` at the repo root, if it exists: the project's hot paths, its measured-but-unfixed performance problems, and any overrides. Where it disagrees with the two files above, it wins.

The files are the source of truth. If this procedure disagrees with them, they win. Never invent a rule: something that looks wrong but no rule covers goes under "Not covered".

## 2. Scope

Use the scope and file list the caller passed. If a person invoked you directly, resolve the argument as `code-standards/skills/review/scope.md` says. State the scope at the top of the report.

## 3. Find the hot paths

The hot paths are the code `PERFORMANCE.md` describes (per event, per frame) and `STANDARDS.local.md` lists by name. Trace what the changed lines call and what calls them, by reading the code and with `grep`. Say in the report which changed code is on a hot path and which is not.

## 4. Check the style rules marked `review`

Go through every rule in `STYLE.md` whose *Enforced* line includes "review". Re-check this list against the file, which may have more rules than listed here.

**S-FLAT**
- Code that stays within the depth limit only by being awkward: deep closures, `match` arms that each nest again, an `if` ladder that should be one `match` or early returns.
- Missed early returns: `if cond { …long… } else { return }` should be a guard that returns first.
- A loop body that branches twice should call a named function.

**S-QUALIFIED-FNS**
- `use some::module::function;` followed by a bare call into another module. Functions defined in the same file, and methods, are fine. Types and traits are fine imported bare.

**S-NAMES-TYPES / S-NAMES-ABBREVIATIONS / S-NAMES-HONEST**
- Abbreviated type names.
- Abbreviations not in the table, including inside compound names (`slot_idx`, `prev_val`, `cfg`) that clippy's whole-name check misses.
- Names that point at the wrong concept (`*_ptr` that isn't a pointer).
- Bindings named after primitive types (`char`, `str`).

**S-NAMES-STD**
- `get_` prefixes on getters (other than indexed `get`/`get_mut`).
- `to_`/`as_`/`into_` names that don't match the cost and ownership the convention implies.

**S-COMMENTS / S-DOCS**
- `//` comments that say *what* the next line does instead of *why*.
- `///` and `//!` comments that aren't full sentences ending with a period, in every paragraph, list items included.
- `//!` module docs on a module whose name already says what it's for.
- Doc comments that only restate the name or type, or docs on obvious fields, variants or getters. Flag them for removal.
- Docs or comments that explain how confusing code works. The finding is the code: suggest the rename or restructure that makes the comment unnecessary.
- Missing docs where they matter: a type's purpose or invariants, a promise the signature doesn't show, a public function that can panic without `# Panics`.
- `//` text that documents an item and belongs in `///`.

**S-FIELDS**
- A stateful struct with any non-private field: `pub`, `pub(crate)` or `pub(super)`.
- Any struct that mixes visibilities, including `pub(crate)` mixed with private, which clippy's `partial_pub_fields` misses.
- Plain-data structs mutated field by field where building and overwriting a new value would be clearer.

**S-INVARIANTS**
- A stateful struct whose doc comment doesn't state what holds after every public call.
- No `check_invariants`, or one that isn't debug-only, or a public method that can change what it covers and doesn't call it before returning, including on its failing paths.
- A check whose assertion messages describe the failure instead of the rule that should have held, or one that costs as much as the data is long and isn't gated by a size.
- A type that holds other stateful types but whose check doesn't call theirs, or a `&mut` accessor to a part that lets a caller bypass the check.
- No property test in a `fuzz.rs` driving random public-call sequences with the check after each call, one with no shrinking or no committed saved cases, or one without the awkward inputs (empty, huge, past-the-end, wide or zero-width glyphs, invalid input, mid-sequence resizes).
- A plain model that exists (a `String` for a text buffer) and isn't compared against, or a test never shown to fail.

**S-ERRORS / S-ERROR-TEXT**
- A module that can fail without `foo/error.rs` holding `pub enum Error` and `pub type Result<T>`, both re-exported.
- A signature spelling out `Result<T, foo::Error>` where `foo::Result<T>` exists.
- Errors defined elsewhere.
- A function returning another module's `Error` or `Result` without a `#[from]` variant wrapping it.
- Ad-hoc `io::Error::other("...")` or string errors in a library crate.
- Error messages that are capitalized or end with a period.

**S-PANICS**
- `expect` messages that describe the failure instead of the invariant.
- External failures (files, terminal, input) handled with `expect` instead of `Result`.
- `assert!` messages that restate the condition.

**S-BOOLS**
- A single remaining `bool` parameter that doesn't read as "x is true" at the call site.

**S-ARITHMETIC**
- `saturating_*`/`checked_*` where the values can't overflow.
- Plain `-` on a value that can be 0 when the code expects it to be.

**S-MACROS**
- A new `macro_rules!` that a function or generic function could express, or one without the comment saying why.

**S-INLINE**
- Any `#[inline]` attribute.

**S-UNSAFE**
- `#[allow(unsafe_code)]` without `reason = "..."`.
- A `SAFETY:` comment that doesn't argue soundness.

**S-LINT-ESCAPES**
- `#[allow]` placed wider than needed, a crate-level `#![allow]`, or a workspace allow without a comment.

**S-TESTS**
- Behavior changes without a test.
- Tests not in `mod tests` at the bottom of the file, apart from a type's property test, which is in its `fuzz.rs`.
- New behavior observable through the public API with no integration test.
- Assertions without a message saying what the case means, where it isn't obvious.

Also confirm the rules enforced by `lint`, `fmt` or `deps` aren't being sidestepped: `#[allow(clippy::excessive_nesting)]`, an `#[allow]` added just to silence a style lint, a rustfmt skip. A sidestep is a finding under the rule the tool enforces.

## 5. Check the performance rules marked `review`

Go through every rule in `PERFORMANCE.md` whose *Enforced* line includes "review". Re-check against the file.

- **P-MEASURE:** a change described as faster has numbers in the commit body or a benchmark. Optimized code that is harder to read cites the measurement. Nothing from the "only with a benchmark" list (hashers, `SmallVec`, allocators, `target-cpu`) is added without one.
- **P-BOXED:** a new field, enum payload or message that never grows is `Box<[T]>`, `Box<str>`, `Box<Path>` or `Arc<str>`, not `Vec`, `String` or `PathBuf`. A reused scratch buffer may be a `Vec`.
- **P-NO-ALLOC-HOT:** `Vec::new`, `vec![]`, `String::new`, `format!`, `to_string`, `to_owned`, `clone` of an owning type, `collect` and `Box::new` inside a hot path.
- **P-BORROW:** a hot function that returns data that already exists but returns an owned copy or a `Vec`.
- **P-OUT-BUFFER:** a hot function that builds a collection but returns it instead of clearing and filling a buffer it is given. Also a function that takes a buffer and appends without clearing, with no `extend_` name.
- **P-REUSE / P-CAPACITY:** a collection rebuilt per call that could live in the calling struct, `a = b.clone()` where `clone_from` fits, a `Vec` grown when its size is known.
- **P-SIZES:** a new hot type that is large, or a large enum variant that isn't boxed. Say how big it is when you can tell.
- **P-ITERATORS:** `collect` only to iterate again, indexing in a loop an iterator expresses, `filter` then `map`, `chunks` where `chunks_exact` fits, a custom iterator without `size_hint`.
- **P-OUTPUT:** terminal output not built in one reused buffer and written once per frame, or a lock held longer than that write.
- **P-BUILD:** a profile change in `Cargo.toml` that undoes the shipped settings, or an inline attribute (also S-INLINE).

Don't repeat a problem already listed in the project's known-opportunities table in `STANDARDS.local.md`. Report it only if the change makes it worse, and say if the change fixes a row, so the row can be removed.

## 6. Validate against both documents

Step 4 and step 5 look for problems. This step makes sure you didn't miss any. Do it every time, even when they found nothing.

1. **Walk both files top to bottom.** For every `S-…` and `P-…` rule, including the ones a tool enforces, check the code in scope against the rule's text as written, not against your memory or this file's summary. The tools may not have run, code behind a `cfg` is invisible to them, and a sidestep defeats them. Record one result per rule: **pass**, **finding**, or **n/a**.
2. **Sweep every comment, not a sample.** List every `//`, `///` and `//!` line in scope (for example `grep -nE '^\s*//'`, limited to changed lines for a diff). Check each against S-COMMENTS and S-DOCS: does a `//` explain *why*, is a `///` full sentences adding something the name and type don't, should it be `///` instead of `//` or deleted, is it propping up code that should be clearer.
3. **Sweep every name introduced or changed:** types, functions, fields, bindings and closure parameters, against S-NAMES-* and the abbreviation table.
4. **Sweep every struct:** plain data or stateful, field visibility against S-FIELDS, and for a stateful one that it states, checks and fuzzes its invariants.

A rule the files have that this procedure doesn't mention still gets checked. This step is driven by the files, not by the lists above.

## 7. Verify every finding

Before reporting, go back to each finding:

- Re-open the file at the line and confirm the code is there as you describe it.
- Quote the exact sentence of `STYLE.md` or `PERFORMANCE.md` that the code breaks. If you can't, it isn't a violation: move it to "Not covered" or drop it.
- Confirm the code really is on a hot path, when the rule is about hot paths.
- Make sure the suggested fix follows both files: names, comments, nesting, error handling.

When the code under review is code you just wrote, review it exactly like anyone else's, every comment you added included. Don't quietly fix what you find. Report it.

## 8. Report

Start with a one-line verdict: how many findings, and whether the change is in line with the standards. List the findings most important first: panics and errors, then hot-path performance, then flatness and naming, comments last. Number them so they can be picked, each as:

```
src/editor/keymap.rs:38  P-NO-ALLOC-HOT  (hot: Editor::apply)
  `actions.clone()` allocates a Vec on every key press.
  → return `&[Action]` from the leaf (P-BORROW) and iterate it
```

Each finding has the `file:line`, the rule id, one or two sentences on what's wrong, and the concrete fix after `→`. Group repeats of the same problem into one finding that lists every location.

Then add:

- **Rule checklist:** every `S-…` and `P-…` id with its result from step 6, one line each (`S-FLAT pass`, `S-DOCS finding (3)`, `S-UNSAFE n/a`).
- **Comments checked:** how many comment lines the sweep covered.
- **Hot paths touched:** the changed functions on one, or "none".
- **Tools:** what you ran or traced with, or that you couldn't run commands.
- **Not covered:** things that look off but no rule covers, phrased as questions for the person.

If you find nothing, say so plainly. Don't pad the report with praise or nitpicks outside the rules.

**Ask only when a person invoked you directly:** end by asking what to implement, **all**, **some** by number, or **none**, using the question tool if the harness has one, then stop and wait. Whoever implements the chosen fixes implements only those, follows both files while doing it, and can run this review again on the result.
