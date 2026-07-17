---
name: reviewing-swift-api-design
description: Use when auditing a Swift package, framework, module, or exposed API for adherence to the Swift API Design Guidelines, especially before release, source-stability commitments, or naming, argument-label, and documentation review.
---

# Reviewing Swift API Design

## Overview

Review as a skeptical caller. Judge semantics, documentation, and calls—not spelling alone.

**Core principle:** checking is not fixing. The only project change is the review artifact.

## Contract

- Edit nothing except `SWIFT_API_DESIGN_REVIEW.md`.
- Declarations prove mechanical rules; semantic rules need semantics plus a use site.
- Evidence containing “if,” “presumes,” “confirm,” or “not shown” is a `CONCERN`, not a `VIOLATION`.
- Record documentation gaps and compliant traps (`NON-ISSUES`). Tooling does not prove clarity.
- Exclude advice without a direct rule. Report candidates only for proven intent, with compatibility risk.

## Workflow

1. Define modules/access levels; inventory declarations, overloads, docs, and calls. Prioritize `public`, `open`, and `package` without dropping requested internal API.
2. Read supplied guidelines or [REFERENCE.md](REFERENCE.md); establish ecosystem/domain precedent.
3. Record non-mutating validation and its limits.
4. Apply every lens to declaration/use-site pairs.
5. Classify findings with exact evidence and change risk.
6. Write only `SWIFT_API_DESIGN_REVIEW.md`; end with a reference-defined verdict.

## Quick Reference

| Lens | Check |
|---|---|
| Clarity | necessary words, role names, weak types |
| Fluency | grammar, factories, side effects, mutation pairs, Booleans, protocols |
| Terminology | established meanings, abbreviations, precedent |
| Conventions | complexity, members/free functions, case, overload meaning |
| Parameters | documentation names, defaults, conversions, labels |
| Documentation | summaries and every declaration in scope |
| Compound API | tuple/closure labels, polymorphic ambiguity |

## Rationalizations

| Excuse | Reality |
|---|---|
| “The owner approved it; the deadline makes a report bureaucracy.” | Authority, diff size, and urgency do not supply semantics. The report is the deliverable. |
| “Everything is green.” | Tooling does not judge semantic names or grammatical calls. |
| “The ask was naming, not docs.” | Documentation is a fundamental guideline. |
| “Static + return type means factory.” | Shape does not prove construction; inspect behavior or record a `CONCERN`. |
| “This primitive should be an enum.” | No direct rule means no finding in this audit. |

## Red Flags — Stop

- Editing anything except `SWIFT_API_DESIGN_REVIEW.md`.
- A `VIOLATION` that also requests semantic confirmation.
- Judging a name without behavior and a representative call.
- Treating tooling as conformance proof.
- Omitting documentation gaps or checked non-issues.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Declaration-only style notes | Show and read the resulting call. |
| Guessed rename | Record missing evidence as a `CONCERN`. |
| Extending one rule by analogy | Report only what the cited rule requires. |
| Fixing during review | Put a grounded candidate and risk in the report only. |
| Blanket “looks good” | State scope, evidence gaps, and defined verdict. |

Detailed rules, report template, and worked example: [REFERENCE.md](REFERENCE.md).
