# Swift API Design Review — Reference

Use with `SKILL.md`. This is a review checklist distilled from the Swift API Design Guidelines mirror supplied for this skill. Canonical source: <https://swift.org/documentation/api-design-guidelines/>.

## Evidence Standard

Every report item contains:

- **Location:** file, line, and declaration.
- **Use:** an existing or minimal representative call.
- **Classification:** `VIOLATION`, `DOCUMENTATION GAP`, `CONCERN`, or `NON-ISSUE`.
- **Rule:** the guideline heading or rule, not “Swift style.”
- **Evidence:** behavior, docs, implementation, precedent, or observed ambiguity.
- **Candidate:** a signature only when semantics establish one.
- **Impact:** what a caller may misunderstand.
- **Change risk:** source-breaking, behavior-affecting, nonbreaking, or unknown.
- **Verification:** command, call-site inspection, or reason no runtime check applies.

A declaration alone can confirm mechanical rules such as casing. Rules about clarity, grammar, side effects, conversion, and role usually require semantics and a use site.

Semantic shape is not semantic proof. A `static` method returning `Widget` from `Configuration` does not prove it constructs a new `Widget`; non-`mutating` syntax does not prove absence of external side effects; a property signature does not prove its complexity; an unlabeled initializer does not prove conversion semantics. Inspect implementation or authoritative documentation. If a finding still says “confirm,” “presumes,” “if,” or “not shown,” it is a `CONCERN` and cannot be counted as a violation.

## Guideline Lenses

### Fundamentals and Documentation

- Optimize for clarity at the point of use; clarity outranks brevity.
- Write a documentation comment for every declaration in scope.
- Begin with a summary. Describe what a function does and returns, what a subscript accesses, what an initializer creates, and what another declaration is.
- Prefer a sentence fragment ending in a period; use recognized symbol documentation for parameters, returns, throws, complexity, preconditions, and related details.
- The explicit complexity requirement covers computed properties that are not $O(1)$. Do not turn it into a requirement for every nonconstant-time method by analogy.

### Promote Clear Usage

- Include every word needed to avoid ambiguity.
- Omit words that add no salient information, especially repeated type information.
- Name variables, parameters, and associated types by role, not type constraint.
- Compensate for weak types such as `Any`, `NSObject`, `Int`, and `String` with a role noun when needed.

### Strive for Fluent Usage

- Functions and methods should form grammatical English at use sites.
- Factory method base names begin with `make`.
- Initializer and factory first arguments do not continue a phrase begun by the base name.
- Side-effect-free functions read as noun phrases; side-effecting functions read as imperative verb phrases.
- Verb operation pairs use imperative mutating and `-ed`/`-ing` nonmutating names (`sort`/`sorted`). Noun operations use the noun for nonmutating and `form` + noun for mutating (`union`/`formUnion`).
- Boolean methods and properties read as assertions (`isEmpty`, `intersects`).
- Protocols describing what something is use nouns. Capability protocols use `-able`, `-ible`, or `-ing`.
- Other type, property, variable, and constant names read as nouns.

### Use Terminology Well

- Prefer a common word unless a term of art preserves essential precision.
- Use terms of art with their established meaning; do not surprise experts or confuse learners.
- Avoid nonstandard abbreviations. Embrace established programming and domain precedent.

A project-local habit does not by itself override a direct guideline. Record genuine ecosystem or domain precedent as evidence.

### General Conventions

- Document computed-property complexity when it is not $O(1)$.
- Prefer methods and properties to free functions unless no natural `self` exists, the function is unconstrained generic, or function syntax is established domain notation.
- Types and protocols use `UpperCamelCase`; everything else uses `lowerCamelCase`. Case acronyms uniformly with their surrounding convention.
- Overloads may share a base name only for the same meaning or distinct domains. Do not overload only on return type.

### Parameters

- Parameter names should make documentation read naturally.
- Use defaults for a single common value instead of repetitive method families.
- Put defaulted parameters toward the end.
- Production-facing source-location defaults prefer `#fileID`; use `#filePath` only when the full path is operationally useful outside production.

### Argument Labels

- Omit labels when arguments cannot be usefully distinguished.
- Omit the first label for a value-preserving conversion; label narrowing conversions by their semantics (`truncating`, `saturating`).
- If the first argument forms a prepositional phrase, begin its label at the preposition (`remove(at:)`). Keep multi-argument abstractions intact.
- If the first argument forms a correct grammatical phrase with the base name, omit its label and move preceding words into the base name (`addSubview(_)`).
- Label every other argument. Arguments with defaults always have labels.

### Special Instructions

- Label tuple members and name closure parameters in API types.
- Treat `Any`, `AnyObject`, and unconstrained generic overloads as ambiguity risks. Distinguish overlapping operations explicitly (`append(contentsOf:)`).

## Tool Boundaries

| Tool | Useful evidence | Does not prove |
|---|---|---|
| `swift build` / compiler | valid declarations and types | clarity, terminology, fluent grammar |
| `swift test` | covered behavior | uncovered API quality or naming |
| DocC | symbol extraction and valid markup | accurate, complete, useful prose |
| `swift-format` | formatting and configured lint rules | semantic API-guideline adherence |
| symbol graph / `.swiftinterface` | exported-surface inventory | call-site readability |
| API digester | source/ABI differences | whether either design is good |

## Verdicts

- `NONCONFORMING`: one or more confirmed `VIOLATION` or `DOCUMENTATION GAP` findings.
- `INDETERMINATE`: no confirmed violations, but missing semantics, use sites, scope, or validation prevents a full review.
- `CONFORMING`: no confirmed violations after every lens was applied to the declared scope with representative use-site evidence.

Never use `CONFORMING` to mean “the sampled declarations looked fine.”

## Report Template

```text
SWIFT API DESIGN REVIEW — <project/module>

Scope:
  Modules/access levels: <...>
  Guidelines source: <path or URL>
  Files and API inventory: <...>

Baseline:
  <command> — PASS | FAIL | COULD NOT RUN — <limits>

VIOLATIONS:
  [V1] <location and declaration>
       Use: <representative call>
       Rule: <named guideline>
       Evidence: <verified conflict>
       Candidate: <signature, or “intent required”>
       Impact: <caller misunderstanding>
       Change risk: <source-breaking | behavior-affecting | nonbreaking | unknown>

DOCUMENTATION GAPS:
  [D1] <location, missing/inaccurate content, applicable rule>

CONCERNS:
  [C1] <location, suspicion, and evidence needed to decide>

NON-ISSUES CHECKED:
  [N1] <suspicious declaration and why it conforms>

TOOLING LIMITS:
  - <what automated checks did not establish>

VERDICT:
  NONCONFORMING | INDETERMINATE | CONFORMING — <counts and reason>
```

## Worked Example

```swift
public struct Catalog {
  public var empty: Bool
  public mutating func remove(_ position: Index) -> Item
  public static func widget(_ configuration: Configuration) -> Widget {
    Widget(configuration: configuration)
  }
  public mutating func sort()
  public func sorted() -> Self
}

if catalog.empty { showEmptyState() }
let removed = catalog.remove(selectedIndex)
let card = Catalog.widget(cardConfiguration)
```

A grounded review reports:

- `VIOLATION`: `empty` → candidate `isEmpty`; Boolean properties read as assertions. The use becomes `if catalog.isEmpty`. Source-breaking.
- `VIOLATION`: `remove(_:)` → candidate `remove(at:)`; the current call can mean remove the value, while `catalog.remove(at: selectedIndex)` names the index role. Source-breaking.
- `VIOLATION`: `widget(_:)` constructs a new `Widget`; factory methods begin with `make`. Candidate `makeWidget(_:)`. Source-breaking.
- `DOCUMENTATION GAP`: every shown declaration lacks a documentation comment.
- `NON-ISSUE`: `sort()`/`sorted()` is the prescribed mutating/nonmutating verb pair. Do not rename it.

The report contains candidate signatures; the reviewer changes no source or call site.
