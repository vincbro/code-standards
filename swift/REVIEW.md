# Swift review

The procedure for reviewing Swift. The `review` skill sends every `*.swift`, `Package.swift`, `Package.resolved`, `.swiftlint.yml` and `.swift-format` file here. You check the code against [STYLE.md](STYLE.md), the way a careful maintainer would. The compiler (Swift 6 mode), SwiftLint, swift-format and the tests already enforce everything mechanical. Your job is the rules that need judgment. How a screen looks is not covered here: a project that has design rules names their review in `STANDARDS.local.md`.

**You never edit code.** When the `review` skill invoked you, return the findings and the rule checklist and **do not ask** what to implement. When a person invoked you directly, end by asking (step 7).

## 1. Load the rules, every time

Read in full before looking at any code:

1. `code-standards/swift/STYLE.md`: every rule has an id (`W-…`), a reason and an *Enforced* line.
2. `STANDARDS.local.md` at the repo root, if it exists: the project's gate, its extra rules and overrides. Where it disagrees with `STYLE.md`, it wins. Check the project's own rules in the same pass.

The file is the source of truth. Never invent a rule: something that looks wrong but no rule covers goes under "Not covered".

## 2. Scope

Use the scope and file list the caller passed, otherwise resolve the argument as `code-standards/skills/review/scope.md` says. State the scope at the top of the report. Report only on lines the change adds or modifies (whole codebase: group repeats).

## 3. Mechanical sweeps

The gate has run (or the `review` skill said it couldn't). Don't repeat what the compiler and SwiftLint report. These greps find candidates, and you judge each:

```
grep -nE "as!|try!|\w!\s*[.,;)\]}]|\w!$|: Any\b|AnyObject"  <files>      # W-TYPES
grep -nE "\?\?\s*(\"\"|0|\[\]|false)"                       <files>      # W-OPTIONALS: placeholder fallback
grep -nE "default:"                                         <files>      # W-EXHAUSTIVE
grep -nE "UserDefaults|FileManager|JSONSerialization|as\? \[String: Any\]" <files>  # W-BOUNDARY, W-STORAGE
grep -nE "catch\s*\{\s*\}|try\?"                            <files>      # W-ERRORS
grep -nE "DispatchQueue|NSLock|@unchecked Sendable|nonisolated\(unsafe\)|@preconcurrency" <files>  # W-CONCURRENCY
grep -nE "Task\s*(\.detached)?\s*\{|Task\.detached"         <files>      # W-TASKS
grep -nE "\[(weak|unowned) self\]|\bsink\(|addObserver|Timer\.scheduledTimer|var \w*[dD]elegate" <files>  # W-MEMORY
grep -nE "ForEach\(.*id:\s*\\\\\.self|\.id\("               <files>      # W-VIEWS
grep -nE "@State\s+(var|let)|@StateObject\s+(var|let)"      <files>      # W-STATE: must be private
grep -nE "onTapGesture|Font\.system\(size|\.font\(\.system\(size" <files>  # W-A11Y
grep -nE "\bprint\(|debugPrint|\bdump\(|NSLog|TODO|FIXME"   <files>      # W-NO-NOISE
grep -nE "swiftlint:disable"                                <files>      # W-LINT-ESCAPES
grep -nE "DateFormatter\(|NumberFormatter\(|Regex|UIImage\(named|Data\(contentsOf" <files>  # W-PERF in a body
```

## 4. Check every rule

Walk `STYLE.md` top to bottom. For every `W-…` rule, including the tool-enforced ones (a force operator, a `// swiftlint:disable` or `@unchecked Sendable` defeats the tool), check the code in scope against the rule's text as written, not against memory. Record one result per rule: **pass**, **finding**, or **n/a**. The ones that need the most judgment:

- **Correctness first:** `W-BOUNDARY`, `W-STORAGE`, `W-ERRORS`, `W-CONCURRENCY`, `W-TASKS`, `W-MEMORY`, and any project rule about exact values or mirrored types.
- **Types:** `W-TYPES`, `W-OPTIONALS` (a fallback that hides a missing value), `W-ENUMS` (optional-and-flag bags that should be enums), `W-EXHAUSTIVE` (a `default` that swallows new cases), `W-VALUE-TYPES`, `W-IMMUTABLE`, `W-ACCESS`.
- **State and views:** `W-STATE`, `W-VIEWS`. For each `@State` in a view a user can leave and return to, ask whether they would be annoyed to lose it. For each `body`, ask what runs in it on every state change.
- **Structure:** `W-PURE` (rules inline in a view), `W-FLAT`, `W-SIZE`, `W-MODULES`.
- **Names and comments:** `W-NAMES`, `W-NAMES-BOOLS`, `W-COMMENTS`, `W-DOCS`. Sweep every comment in scope, not a sample.
- **Tests:** `W-TESTS`: changed logic has a test that fails without the change; a bug fix has its failing test.

## 5. Verify every finding

Re-open the file at the line and confirm the code is as described. Quote the exact sentence of `STYLE.md` it breaks; if you can't, it isn't a violation. For a logic or concurrency finding, give the input or sequence that goes wrong (the screen that is left while the task runs, the second tap, the old stored value). "Could be better" with no cost is not a finding. Code you just wrote is reviewed like anyone else's.

## 6. Report

One-line verdict. Numbered findings, correctness first, then types, state and concurrency, then structure, tests and names, comments last:

```
Sources/Lesson/LessonView.swift:84  W-TASKS
  `Task { await model.load() }` in `onAppear` isn't cancelled when the view goes away or `item` changes.
  → use `.task(id: item) { await model.load() }`
```

Then: the rule checklist (every `W-…` id and the project's own ids), the gate result or that you couldn't run it, comments checked, and **Not covered** questions.

## 7. Ask (only when a person invoked you directly)

Ask what to implement: **all**, **some** by number, or **none**. Then stop and wait.
