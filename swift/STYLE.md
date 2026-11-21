# Swift style

How Swift is written, for apps on Apple platforms (SwiftUI first, UIKit/AppKit where needed) and Swift packages, in Swift 6 language mode. Most of it is enforced: the project's check fails on anything the compiler, SwiftLint and swift-format can catch. The rest is checked in review, by people or by the review skill (`swift/REVIEW.md`). Every rule has an ID (`W-…`) so a review can cite it. Commit messages are in [COMMITS.md](../COMMITS.md). The counterparts are [rust/STYLE.md](../rust/STYLE.md) and [typescript/STYLE.md](../typescript/STYLE.md).

Naming and API shape follow Apple's [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). This file only adds what those leave open.

Each rule says what to do, **why**, and what enforces it:

- `compiler`: the build with `-swift-version 6` (complete concurrency checking) and warnings as errors
- `lint`: SwiftLint, where each custom or opt-in rule names the `W-…` id it serves
- `fmt`: `swift-format lint --strict`
- `test`: `swift test` or `xcodebuild test` (Swift Testing)
- `review`: nothing automatic. Reviewers and the review skill check it.

The commands that run these are the project's own, listed in its `STANDARDS.local.md`. A project adds its own rules there too (its own ids, never `W-…`).

A rule a tool enforces is not up for debate: fix the code. A rule marked `review` is where judgment comes in: a reviewer flags it with the ID, and the author fixes it or says why this case is the exception.

**Rule ids.** W-TYPES, W-OPTIONALS, W-ENUMS, W-EXHAUSTIVE, W-VALUE-TYPES, W-IMMUTABLE, W-ACCESS, W-BOUNDARY, W-STORAGE, W-ERRORS, W-CONCURRENCY, W-TASKS, W-MEMORY, W-PURE, W-STATE, W-VIEWS, W-FLAT, W-SIZE, W-MODULES, W-IMPORTS, W-NAMES, W-NAMES-BOOLS, W-COMMENTS, W-DOCS, W-A11Y, W-DEPS, W-NO-NOISE, W-LINT-ESCAPES, W-TESTS, W-PERF.

---

## Types

### W-TYPES: The types tell the truth

No force cast `as!`, no force try `try!`, no force unwrap `!`, no `Any` or `AnyObject` where a protocol or generic fits. An implicitly unwrapped optional (`T!`) is allowed only for an `@IBOutlet`. A force operator that remains is allowed only when the line before it proves it and a reader can see why, and then it is a `precondition` or a `guard … else { preconditionFailure("…") }` with a message naming the invariant.

*Why:* a force operator turns a wrong assumption into a crash in front of the user, far from the cause. The compiler already knows which values can be missing.

*Enforced:* lint (`force_cast`, `force_try`, `force_unwrapping`, `implicitly_unwrapped_optional`). Review catches the ones lint allows.

### W-OPTIONALS: Handle the missing case; don't default it away

Unwrap with `guard let` (early exit) or `if let`; use `??` only with a fallback that is correct, never a placeholder that hides the problem (`?? ""`, `?? 0` on data that should exist). Don't return an optional from a function that can fail for a reason: throw. An optional collection is an empty collection.

*Why:* an array can be empty, a dictionary lookup can miss, a stored value can be old. The unhappy case is where the user sees a blank screen or a wrong number.

*Enforced:* lint (`force_unwrapping`). Review checks the fallback is correct.

### W-ENUMS: Model states as an enum with associated values

Values that are valid only together are one `enum` with payloads, not a struct of optionals and flags:

```swift
enum Load<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(LoadError)
}
```

*Why:* a bag of optionals allows combinations that mean nothing (`isLoading` and `error` both set), and every reader has to know which. An enum makes the impossible state unwritable, and `switch` unpacks each case.

*Enforced:* review.

### W-EXHAUSTIVE: A `switch` over your own enum names every case

No `default` in a `switch` over an enum the project owns, and none that swallows a new case with `break`. Over a framework enum that can grow, use `@unknown default` and handle it honestly. Lookup tables over an enum are a `switch` or a function, not a dictionary that can miss a key.

*Why:* when a case is added, the compiler must fail at every place that has to learn about it.

*Enforced:* compiler (exhaustiveness, and the `@unknown default` warning). Review catches a `default` that hides new cases.

### W-VALUE-TYPES: `struct` by default; a `class` earns its place

Use `struct` and `enum`. A `class` is for identity, shared mutable state, or a framework that requires one, and it is `final` unless it is designed for subclassing. No inheritance to share code: use a protocol with an extension, or composition.

*Why:* values can't be changed under you, copy cheaply (copy-on-write) and need no `[weak self]`. A class brings aliasing, reference cycles and thread-safety questions.

*Enforced:* lint (`final_class` opt-in rule). Review checks the choice.

### W-IMMUTABLE: `let` unless it changes

Bindings and stored properties are `let`. A `var` property that nobody mutates after `init` is a `let`. Data a view or a model receives is passed in as `let`; build a new value instead of changing one in place.

*Why:* every `var` is a thing that can change under the reader. The compiler warns on a local, but not on a property.

*Enforced:* compiler (never-mutated local `var`). Review for properties.

### W-ACCESS: Everything is as private as it can be

Declarations are `private` unless something else needs them, then `internal`. `public` is for the API of a package, and an `open` class is a decision. Mark a property `private(set)` when only the type changes it. Don't write `internal` explicitly. `fileprivate` only when two types in the file need it.

*Why:* the surface is what you must keep working. A property others can set cannot keep an invariant.

*Enforced:* lint (`private_over_fileprivate`, `redundant_internal_acl` custom rule). Review checks that nothing is wider than its callers need.

---

## Boundaries and errors

### W-BOUNDARY: Untrusted input is decoded, not assumed

Data from `UserDefaults`, files, the network, `JSONSerialization`, a deep link, the pasteboard and an XPC or extension is decoded into a type with `Codable` at the edge, with a fallback or a thrown error for a missing or old shape. After the edge the types can be trusted. No `[String: Any]` past the edge. A `Decodable` accepts the previous version's shape (a default via `decodeIfPresent`), and a new required field is a migration.

*Why:* what was stored by last week's version, or a file the user edited, will not match the type you wrote today. A cast turns that into a crash deep in a view.

*Enforced:* lint (custom rule banning `JSONSerialization` and `as? [String: Any]` outside the boundary module). Review checks the fallbacks.

### W-STORAGE: Persistence is wrapped, namespaced and tolerant

Reads and writes of `UserDefaults`, the keychain, files and the database go through one module per store. No `UserDefaults.standard` or `FileManager` in a view or model. Keys share one project prefix (or live in a typed key enum). A reader accepts the previous shape. A destructive reset is an explicit action, never a side effect. Secrets are in the keychain, never in `UserDefaults` or the source.

*Why:* storage can fail or be empty, and the user's progress and work live there.

*Enforced:* lint (custom rules for `UserDefaults.standard` and `FileManager.default` outside the store). Review checks the rest.

### W-ERRORS: No silent failure

No empty `catch`, and no `try?` that throws away an error the user or a log should hear about. Use `try?` only where "absent" and "failed" really mean the same and a comment says so. A failure the user can cause becomes a message in the view; one they can't becomes a visible "can't tell" state or a logged bug note, never a blank screen. Errors are `enum`s conforming to `Error`, one per module, with a `LocalizedError` message that is a lowercase fragment (S-ERROR-TEXT in `rust/STYLE.md`). Use typed `throws(MyError)` where the set is closed. A `Task` result is read, not dropped.

*Why:* an honest "can't tell" is better than a blank pane or a stale result.

*Enforced:* lint (custom rules for an empty `catch` and for `try?`). Review checks the rest.

---

## Concurrency and memory

### W-CONCURRENCY: Isolation is explicit and checked by the compiler

The project builds in Swift 6 language mode with complete checking; no downgrade to warnings. UI types, view models and anything that touches a view are `@MainActor`. State shared across tasks lives in an `actor` or is `Sendable` by construction. No `DispatchQueue` or `NSLock` in new code, and no completion-handler API without an `async` wrapper. `@unchecked Sendable`, `nonisolated(unsafe)` and `@preconcurrency` carry a comment saying what makes them safe or why the import can't be fixed.

*Why:* data races are the bugs you can't reproduce. The compiler can prove their absence, but only if nothing switches the checking off.

*Enforced:* compiler (Swift 6 mode). Lint (custom rules for `DispatchQueue`, `@unchecked Sendable`, `nonisolated(unsafe)`). Review checks the comments and the actor boundaries.

### W-TASKS: Work has an owner and can be cancelled

A `Task` is started from a place that owns it: the `.task` modifier, a stored handle that is cancelled in `deinit` or on replacement, or a task group. No fire-and-forget `Task {}` in a loop or in `init`. No `Task.detached` without a comment saying why it must leave the actor. A long loop or a chain of awaits checks `Task.checkCancellation()` or `Task.isCancelled`. Prefer `async let` and task groups to unstructured tasks.

*Why:* a task nobody owns outlives its screen, writes to a view that is gone and can't be stopped. Searches and typing produce many; the last one must win.

*Enforced:* lint (custom rule for `Task.detached`). Review checks ownership and cancellation.

### W-MEMORY: No cycles, no hidden captures

A closure that is stored (a handler, a callback, a Combine sink, a `Task` kept in a property) and refers to `self` captures `[weak self]` and handles `nil` by returning, or captures only the values it needs. `unowned` only when the lifetime is guaranteed by construction, with a comment. A delegate property is `weak`. Notification and timer observers are removed. In a struct or a view no `[weak self]`: it has none.

*Why:* a retain cycle is a leak that grows with use and shows up as a memory warning, not a failing test.

*Enforced:* lint (`weak_delegate`, `unowned_variable_capture`). Review checks the captures.

---

## Structure

### W-PURE: Logic lives outside views, with a test

Anything with a rule in it (choosing what to show, grading, scheduling, layout maths, text processing, parsing, formatting) is a plain function or value type in its own file with a test. A view is layout and wiring; a view model calls the logic and holds state.

*Why:* a pure function is tested in milliseconds with no UI. Logic inside a view can only be tested by tapping.

*Enforced:* review.

### W-STATE: State has one owner and no copies

State that can be computed from other state is a computed property, not stored. State two views need lives above both, in an `@Observable` model passed down. `@State` and `@StateObject` are `private` and own state that only that view cares about. A child gets `let` for read-only data, `@Binding` for a value it edits, and the model itself only when it uses most of it. State that is meaningful to the user (a step reached, a typed answer, a filter) is not a bare `@State` in a view they can leave. Use `@Observable` (Observation), not `ObservableObject` with `@Published`, for new code, and `@Bindable` to bind into it.

*Why:* two copies disagree, and the user sees the stale one. Lost state costs them their place.

*Enforced:* lint (custom rule: `@State` and `@StateObject` must be `private`). Review checks the rest.

### W-VIEWS: A view's `body` is cheap, pure and small

`body` describes the view from the state and does nothing else: no network, no storage, no sorting or filtering of a big collection, no creating a model, no `print`. Work goes in `.task`, `.onChange` or the model. Break a `body` into small `View` structs, not into computed properties that hide the same size, once it passes a screenful. Identity is stable: `ForEach` uses an `Identifiable` with a real id, never `\.self` on a value that can repeat or `indices` on a list that changes. An id that resets a view's state (`.id(x)`) is a decision: say why in a comment. Modifier order is meaning (`padding` before `background`): don't reorder without looking.

*Why:* SwiftUI calls `body` whenever state changes, as often as a frame. Side effects in it run at times you don't control, and an unstable id throws away state and animation.

*Enforced:* lint (custom rule flagging `ForEach(…id: \.self)` as a candidate). Review checks the rest.

### W-FLAT: Keep code flat

No more than four levels of nesting. Return early (`guard`), extract a named function, `switch` on an enum instead of an `if` ladder, and give a `ForEach` or `map` closure with branches its own view or function. Never nest closures more than two deep.

*Why:* the same as S-FLAT in `rust/STYLE.md`: every level is one more condition to hold in your head.

*Enforced:* lint (`nesting`, `cyclomatic_complexity`). Review flags code that passes only by being awkward.

### W-SIZE: Files and functions stay readable

A type over about 300 lines, a function over about 50, or a file over about 500 needs a reason. Flag what makes it hard to follow, not the count alone. One idea per file; extensions that add a conformance go in the same file as the type unless they are large. Split by what changes together, not by kind (not a `Views/` of 40 unrelated files).

*Enforced:* lint, partly (`type_body_length`, `function_body_length`, `file_length` fail above the generous limits). Review judges the rest.

### W-MODULES: One way in, no cycles

Modules form layers (models and data at the bottom, storage and logic above, views at the top). A lower module never imports a view or `SwiftUI`. No import cycles between targets. Split code into a Swift package target when a layer needs a compile-time boundary. A target imports from a few places, not from every module.

*Why:* cycles make build order matter, and `import SwiftUI` in the logic layer pulls the UI into every test.

*Enforced:* compiler (SwiftPM refuses cycles), lint (custom rule for `import SwiftUI` in the logic target). Review checks the direction.

### W-IMPORTS: Imports are sorted and minimal

Imports are alphabetical, one per line, with `@testable import` last and only in tests. Import the narrowest module (`Foundation`, not `UIKit`, when that is all you use). Nothing imported and unused. Use `import struct Module.Type` only to resolve a name clash.

*Enforced:* lint (`sorted_imports`, `unused_import`, `duplicate_imports`) and fmt (`OrderedImports`).

---

## Names, comments, docs

### W-NAMES: A name says what the thing is

Follow the API Design Guidelines: clarity at the call site, no needless words, methods named by role (`removeAll`, `makeIterator`, `x.distance(to: y)`), mutating and non-mutating pairs (`sort`/`sorted`). Types and protocols are nouns (`UpperCamelCase`), protocols for capabilities end in `-able`/`-ible`/`-ing`. No abbreviated type names (`Expression`, not `Expr`; S-NAMES-TYPES in `rust/STYLE.md` applies here too). Elsewhere only the abbreviations everyone knows: `id`, `url`, `i`/`j`/`n`, `min`/`max`. Acronyms are cased as words (`userID`, `URLSession`, `htmlParser`). A value is named for what it holds, not how it is computed. No `Manager`, `Helper` or `Utils` that has no more specific name. A view model is `FooModel` or `FooViewModel`, one per project.

*Enforced:* lint (`identifier_name`, `type_name`). Review checks the rest.

### W-NAMES-BOOLS: A boolean reads as an assertion

`isOpen`, `hasHint`, `canSubmit`, `shouldRetry`, not `open`, `hint`, `submit`. At the call site it reads as English: `if list.isEmpty`. A type with two flags is two properties or an enum (`mode: .submit`), not `a` and `b`. A function parameter that is a `Bool` has a label that says what `true` means; two `Bool` parameters are an enum.

*Why:* at the call site you only see `true`.

*Enforced:* review.

### W-COMMENTS: `//` comments say why

A `//` comment carries the reasoning the code can't show. It never restates the next line. No commented-out code. `// MARK: -` divides a long file into the sections it already has and is never a substitute for splitting it.

*Enforced:* review. (W-NO-NOISE covers `TODO`.)

### W-DOCS: `///` adds what the name and type can't say

A `///` doc comment goes on a declaration that is `public`, or any type, when it says what it is for, what it promises, or what it keeps true (an invariant, a unit such as "UTF-16 code units", the reason a key resets state). Don't document what the name and type already say, and don't add `- Parameter` lists that repeat the labels. Use `- Throws:` for the errors a caller must handle and `- Precondition:` for what the caller must guarantee. When a doc is explaining how confusing code works, the fix is clearer code. Docs are full sentences ending with a period. DocC symbols link with double backticks.

*Why:* docs that exist only where they add insight get read.

*Enforced:* lint (`orphaned_doc_comment`, `invalid_docs`) for form; review for content.

---

## Accessibility and dependencies

### W-A11Y: Built in, not added later

An interactive thing is a `Button`, `Toggle`, `Link` or other control, never `Text` with `.onTapGesture`. An image-only control has an `accessibilityLabel`; a decorative image is hidden. Text uses Dynamic Type (a text style or `@ScaledMetric`), no fixed font sizes for body text. Colour is never the only carrier of meaning, and contrast works in light and dark and with Increase Contrast. Motion respects Reduce Motion. User-facing strings are `LocalizedStringKey` or `String(localized:)`, not concatenated.

*Why:* it is the cheapest accessibility there is, and the controls come with focus, keyboard and VoiceOver behaviour for free.

*Enforced:* lint (custom rule for `onTapGesture`; `grep -n "onTapGesture"`). Review checks the rest.

### W-DEPS: A dependency is earned

A new package has a reason and is used. Swift Package Manager only; versions pinned to a range (`from:`), and `Package.resolved` is committed. Prefer the platform framework to a package for something it does (`URLSession`, `Codable`, Observation, Swift Testing). No second library for something an existing one does. Prefer a few lines of code to a package for something small.

*Enforced:* review.

### W-NO-NOISE: No leftovers

No `print`, `debugPrint`, `dump` or `NSLog`; log through `Logger` (`os`) with a subsystem, a category and the right level, and mark user data `.private`. No commented-out code, dead types, unused files or `#if DEBUG` code that ships behavior. A `TODO` or `FIXME` names the issue that tracks it.

*Enforced:* lint (custom rules for `print`, `todo` format; `unused_declaration` in `analyze`) and the compiler for unused values. Review for the rest.

### W-LINT-ESCAPES: A lint exception is narrow and says why

`// swiftlint:disable` applies to one line (`:next` or `:this`), names one rule, and has a reason after `-`. No file-wide or `:all` disable, and no disable of a rule that enforces a `W-…` id without a matching entry under Overrides in `STANDARDS.local.md`. The same for `#if` that hides code from the build.

*Enforced:* lint (`blanket_disable_command`, `superfluous_disable_command`). Review checks the reason.

---

## Tests and speed

### W-TESTS: Behaviour has a test, written first for a bug

Logic added or changed has a Swift Testing test (`@Test`, `#expect`, `#require`) that fails without the change; XCTest is only for what Swift Testing can't do (UI tests, performance metrics). For a bug, write the failing test from the input you saw, then fix it. Test names say the behaviour in a sentence. A test drives the logic with real data, not mocks of it; where a dependency must be replaced, it is a protocol the real code also uses, not a mock framework. A test that waits uses `confirmation` or an async expectation, never `sleep`. A UI behaviour that matters (state kept after navigating, a preview appears) gets a UI or snapshot test.

*Why:* the same as Rust: end-to-end tests catch what a user hits.

*Enforced:* test (it runs); review checks that the change comes with one.

### W-PERF: Keep the per-frame and per-input path light

Code that runs per frame, per scroll step or per keystroke (a `body`, a `Canvas`, a drawing or layout function, a text-change handler) doesn't repeat work it already has: derive once into the model, and don't build formatters (`DateFormatter`, `NumberFormatter`, `Regex`) or decode images in it. Long lists use `LazyVStack`/`List`. Heavy work leaves the main actor. Don't optimise by feel: when a change is made for speed, say what was measured (Instruments, `measure`, a benchmark), the same as P-MEASURE in `rust/PERFORMANCE.md`.

*Why:* any lag between a touch and the response is felt, and a dropped frame is a dropped frame.

*Enforced:* review.
