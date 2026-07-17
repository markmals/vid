# SWIFT API DESIGN REVIEW — `vid`

## Scope

- **Module and access levels:** executable module `vid`. No `public`, `open`, `package`, `internal`, or `fileprivate` modifiers occur in `Sources/vid`; every non-`private` production declaration therefore has implicit `internal` access. This review covers that complete internal production API because the requested scope is the application API, not only an exported library surface.
- **Included files:** all 20 Swift files under `Sources/vid`, grouped under the root command, `CLI`, `Encode`, `Media`, `Remux`, `Repair`, and `Subtitles`.
- **Included declarations:** command and option types, media model and settings types, `MediaPlan`, plan implementations, probing and processing APIs, output transactions, subprocess execution, errors, and their non-private members. Synthesized memberwise initializers were assessed at observed call sites.
- **Excluded implementation details:** `private` declarations (`RemuxWorkflow`, `AddSubtitleWorkflow`, `SidecarTransaction`, `CommandPreview`, and private helper members) and test-only helpers. Tests were used as caller evidence.
- **Overloads and compound types:** no production overload set, tuple API, or closure parameter appears in scope.
- **Guidelines source:** `.agents/skills/reviewing-swift-api-design/REFERENCE.md`, distilled from the [official Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).
- **Domain precedent:** Swift Argument Parser command requirements and help-generation conventions; FFmpeg media terms and codec spellings used by the command-line domain.

## Baseline

- `swift build` — **PASS**. Establishes that declarations and call sites compile; it does not establish semantic naming or documentation quality.
- `swift test` — **PASS**. Five tests across two suites passed; coverage establishes selected file-transaction and FFmpeg-plan behavior, not API-guideline conformance.
- `swift format lint --recursive Sources Tests` — **PASS**. Establishes configured formatting only.
- `swift run --skip-build vid --help` — **PASS**. The generated command surface is coherent and includes all five top-level command groups; this does not assess internal Swift call grammar.
- Documentation-comment search (`^\s*///|^\s*/\*\*`) — **PASS as inventory evidence**: zero documentation comments occur under `Sources/vid`. This establishes the documentation gaps below.
- LSP symbol and reference inspection — **PASS** for the named use sites below. LSP establishes symbol relationships, not whether names are clear.

## Violations

### V1 — Boolean properties do not consistently read as assertions

- **Location:**
  - `Sources/vid/CLI/CommandOptions.swift:9,26,29,32` — `recursive`, `replace`, `removeSource`, `overwrite`.
  - `Sources/vid/Remux/RemuxCommands.swift:17` — `appleCompatible`.
  - `Sources/vid/Encode/EncodeCommand.swift:36,39` — `normalizeDispositions`, `skipHEVC`.
  - `Sources/vid/Subtitles/SubtitleCommands.swift:33,66` — `removeSubtitle`, `removeSubtitles`.
  - `Sources/vid/Media/MediaSettings.swift:14,23` — `appleCompatible`, `normalizeDispositions`.
  - `Sources/vid/Media/OutputTransaction.swift:5-7` — `overwrite`, `removeSource`, `replace`.
- **Use:** `settings.appleCompatible` controls Apple tagging at `RemuxPlan.swift:31`; `settings.normalizeDispositions` controls normalization at `EncodePlan.swift:46`; `policy.replace`, `policy.removeSource`, and `policy.overwrite` control output behavior at `OutputTransaction.swift:41,58,65`.
- **Classification:** `VIOLATION`.
- **Rule:** “Boolean methods and properties should read as assertions.”
- **Evidence:** The domain-model expressions read as commands or fragments rather than assertions: `settings.appleCompatible`, `settings.normalizeDispositions`, `policy.replace`, and `policy.overwrite`. The command-layer flag properties carry the same non-assertive forms into Swift call sites.
- **Candidates:**
  - Domain models: `isAppleCompatible`, `shouldNormalizeDispositions`, `shouldOverwriteExistingOutput`, `shouldRemoveSource`, and `shouldReplaceInput`.
  - Command options: `includesSubdirectories`, `shouldReplaceInput`, `shouldRemoveSource`, `shouldOverwriteExistingOutput`, `isAppleCompatible`, `shouldNormalizeDispositions`, `shouldSkipHEVCInputs`, `shouldRemoveSubtitle`, and `shouldRemoveMatchedSubtitles`.
  - Preserve the existing CLI spellings with explicit Argument Parser names such as `.customLong("replace")`, `.customLong("skip-hevc")`, and the existing `-r`/`--recursive` pair.
- **Impact:** Callers must mentally reinterpret imperative flag spellings as state. Assertive names expose the Boolean contract directly without changing command-line vocabulary.
- **Change risk:** **Source-breaking** inside `vid`; **behavior-affecting** only when generated CLI names are not pinned explicitly.
- **Verification:** LSP references for `appleCompatible`, `normalizeDispositions`, `overwrite`, and `replace` resolve to the branch and initializer uses listed above.

### V2 — `requireVideo` is imperative despite being side-effect-free, and its first argument is not grammatical

- **Location:** `Sources/vid/Media/FFmpegPlanSupport.swift:13` — `static func requireVideo(_ probe: MediaProbe, input: URL) throws -> MediaStream`.
- **Use:** `FFmpegPlanSupport.requireVideo(probe, input: input)` occurs in `EncodePlan.swift:12`, `RemuxPlan.swift:12`, `RepairPlan.swift:11`, and `AddSubtitlePlan.swift:14`.
- **Classification:** `VIOLATION`.
- **Rule:** side-effect-free functions read as noun phrases; a first argument that forms a prepositional phrase begins its label at the preposition.
- **Evidence:** The implementation only selects and returns `probe.firstVideoStream` or throws. It performs no mutation or external operation. `requireVideo(probe, input:)` reads as an imperative acting on `probe`, while `probe` is actually the collection being searched.
- **Candidate:** `static func requiredVideoStream(in probe: MediaProbe, input: URL) throws -> MediaStream`.
- **Impact:** The candidate makes the returned entity and the probe’s source role visible at every plan call site.
- **Change risk:** **Source-breaking** inside `vid`; behavior-preserving.
- **Verification:** Implementation inspection at `FFmpegPlanSupport.swift:13-18` and LSP references across all four plan implementations.

### V3 — `appendTextSubtitleCodec` describes only one of its two behaviors

- **Location:** `Sources/vid/Media/FFmpegPlanSupport.swift:99` — `appendTextSubtitleCodec(when:to:)`.
- **Use:** `FFmpegPlanSupport.appendTextSubtitleCodec(when: subtitles, to: &arguments)` at `RemuxPlan.swift:28` and `EncodePlan.swift:38`.
- **Classification:** `VIOLATION`.
- **Rule:** include every word needed to avoid ambiguity; do not use terminology that misstates the operation.
- **Evidence:** A nonempty stream list appends the `mov_text` codec option, while an empty list appends `-sn`, which disables subtitle output. The current base name promises codec appending even on the disabling path.
- **Candidate:** `static func appendSubtitleOutputOptions(for streams: [MediaStream], to arguments: inout [String])`.
- **Impact:** Callers can understand that the helper selects complete subtitle-output behavior, not merely a codec.
- **Change risk:** **Source-breaking** inside `vid`; behavior-preserving.
- **Verification:** Implementation inspection at `FFmpegPlanSupport.swift:99-108` and both LSP-resolved calls.

### V4 — `ToolRunner.capture` and `ToolRunner.stream` omit the object of the operation

- **Location:** `Sources/vid/Media/ToolRunner.swift:4,23` — `capture(_:arguments:)` and `stream(_:arguments:)`.
- **Use:** `runner.capture("ffprobe", arguments: ...)` at `MediaProbe.swift:90`; `runner.stream("ffmpeg", arguments: ...)` at `MediaProcessor.swift:53,74`.
- **Classification:** `VIOLATION`.
- **Rule:** include every word needed to avoid ambiguity; methods should form grammatical English at use sites; first prepositional arguments carry the preposition in their labels.
- **Evidence:** The methods execute a named tool and respectively capture or stream its output. The current calls read as capturing or streaming the executable itself. `standardOutput`, `currentStandardOutput`, and `currentStandardError` in the implementations establish that output is the operated-on value.
- **Candidates:**
  - `func captureOutput(of tool: String, arguments: [String]) async throws -> String`
  - `func streamOutput(of tool: String, arguments: [String]) async throws`
- **Impact:** The calls state both the subprocess side effect and the output mode without repeating `run` from the enclosing `ToolRunner` type.
- **Change risk:** **Source-breaking** inside `vid`; behavior-preserving.
- **Verification:** Implementation inspection at `ToolRunner.swift:4-40` and LSP references in `MediaProber` and `MediaProcessor`.

### V5 — `operationName` is actually an output-filename suffix, and one value uses an unclear abbreviation

- **Location:**
  - `Sources/vid/Media/MediaPlan.swift:4` — `var operationName: String { get }`.
  - `Sources/vid/Media/OutputTransaction.swift:19,50` — initializer label and filename interpolation.
  - `Sources/vid/Subtitles/AddSubtitlePlan.swift:4` — value `"subbed"`.
- **Use:** `MediaProcessor.swift:34` passes `plan.operationName` to `OutputTransaction`; the transaction uses it only in `"\(baseName).\(operationName).mp4"`.
- **Classification:** `VIOLATION`.
- **Rule:** include every word needed to avoid ambiguity; prefer common words over unclear abbreviations; properties read as nouns.
- **Evidence:** The value does not identify dispatch, logging, or an operation object. It solely supplies a filename suffix when the ordinary `.mp4` output would collide with the input. `"subbed"` is an informal shortening that can also mean dubbed or substituted, while this operation adds a subtitle track.
- **Candidates:**
  - `MediaPlan.outputFilenameSuffix`
  - `OutputTransaction.init(sourceURL:outputFilenameSuffix:policy:)`
  - `AddSubtitlePlan.outputFilenameSuffix = "subtitled"`
- **Impact:** The API states the value’s actual role and produces an unambiguous subtitle-related suffix.
- **Change risk:** **Source-breaking** inside `vid`; changing `"subbed"` to `"subtitled"` is **behavior-affecting** because an MP4 input receives a different output filename.
- **Verification:** LSP shows the protocol requirement flowing to `MediaProcessor.swift:34`; `OutputTransaction.swift:48-51` establishes its sole behavior.

### V6 — Path-bearing `VidError` cases use unlabeled weak `String` values

- **Location:** `Sources/vid/Media/VidError.swift:4-9,11` — `emptyOutput(String)`, `fileDoesNotExist(String)`, `invalidOutputDirectory(String)`, `noVideoStream(String)`, `outputExists(String)`, and `unreadableProbe(String)`.
- **Use:** representative call `VidError.emptyOutput(temporaryURL.path)` at `OutputTransaction.swift:97` and `MediaProcessor.swift:149`; equivalent path strings are passed by the other cases.
- **Classification:** `VIOLATION`.
- **Rule:** name parameters by role rather than type; compensate for weak types such as `String` with a role noun when needed.
- **Evidence:** Calls expose only a bare string. The implementation consistently interprets each value as a filesystem path, a role that is absent from the associated-value declarations and construction calls.
- **Candidates:** `emptyOutput(path:)`, `fileDoesNotExist(path:)`, `invalidOutputDirectory(path:)`, `noVideoStream(path:)`, `outputExists(path:)`, and `unreadableProbe(path:)`.
- **Impact:** Error construction and pattern matching state what each string represents.
- **Change risk:** **Source-breaking** inside `vid`; behavior-preserving.
- **Verification:** LSP references for `emptyOutput` resolve both construction sites and the `errorDescription` pattern; inspection shows the same path role for the remaining cases.

### V7 — `FilePathResolver.resolve` uses an imperative name for a side-effect-free transformation

- **Location:** `Sources/vid/Media/FilePathResolver.swift:4` — `static func resolve(_ path: String) -> URL`.
- **Use:** `FilePathResolver.resolve(path)` at `InputDiscovery.swift:8`, `FilePathResolver.resolve(video)` and `.resolve(subtitle)` at `SubtitleCommands.swift:37-38`, and a function reference at `CommandOptions.swift:40`.
- **Classification:** `VIOLATION`.
- **Rule:** side-effect-free functions read as noun phrases; argument labels should make the call grammatical.
- **Evidence:** The implementation expands a tilde, anchors a relative path to the current directory, standardizes the URL, and returns it. It performs no mutation or externally visible action. The imperative call `FilePathResolver.resolve(path)` does not describe the returned value.
- **Candidate:** `static func resolvedURL(for path: String) -> URL`.
- **Impact:** The call identifies both the result type and the input role: `FilePathResolver.resolvedURL(for: path)`.
- **Change risk:** **Source-breaking** inside `vid`; behavior-preserving.
- **Verification:** Implementation inspection at `FilePathResolver.swift:4-14` and five LSP-resolved references.

## Documentation gaps

### D1 — Every explicit internal production declaration lacks a documentation comment

- **Location:** all 20 files under `Sources/vid`; representative declarations include `Vid`, every command and option type, `MediaPlan`, every plan type, `MediaProbe`, `MediaProcessor`, `OutputPolicy`, `OutputTransaction`, `ToolRunner`, `VidError`, and their non-private members.
- **Use:** representative callers include `InputDiscovery().mediaFiles(at:recursive:)` in `VidTests.swift:20-21`, `plan.makeProcessingPlan(input:output:probe:)` in `MediaPlanTests.swift:25-29`, and `processor.process(_:outputPolicy:plan:probe:)` throughout command implementations.
- **Classification:** `DOCUMENTATION GAP`.
- **Rule:** write a documentation comment for every declaration in scope; begin with a summary and document parameters, returns, throws, and relevant preconditions.
- **Evidence:** the documentation-comment search found no `///` or `/**` comment in `Sources/vid`. Argument Parser `help:` strings document generated CLI options, not the Swift declarations or their throwing and return contracts.
- **Candidate:** add symbol documentation for every non-private production declaration, including `- Parameters:`, `- Returns:`, and `- Throws:` sections where applicable. Type summaries should explain the distinction between source probes, operation plans, processing plans, policies, and transactions.
- **Impact:** Internal callers currently need implementation inspection to learn failure modes, filesystem effects, ownership/removal behavior, and plan invariants.
- **Change risk:** **Nonbreaking**.
- **Verification:** regex documentation inventory across `Sources/vid`; compiler and formatter checks do not supply missing prose.

### D2 — Nonconstant computed-property complexity is undocumented

- **Location:** `Sources/vid/Media/MediaProbe.swift:6,10,14,18,22,54` — `audioStreams`, `bitmapSubtitleStreams`, `firstVideoStream`, `subtitleStreams`, `textSubtitleStreams`, and `MediaStream.language`.
- **Use:** `probe.audioStreams` is consumed by all four plan families; `probe.textSubtitleStreams` and `probe.bitmapSubtitleStreams` are consumed by remux and subtitle plans.
- **Classification:** `DOCUMENTATION GAP`.
- **Rule:** document the complexity of computed properties whose complexity is not $O(1)$.
- **Evidence:** the stream properties call `filter` or `first` over `streams`; `bitmapSubtitleStreams` and `textSubtitleStreams` also derive from another filtered property. `language` lowercases a string. Their work scales with stream count or language-code length, and no complexity documentation exists.
- **Candidate:** document `O(n)` for stream-filtering properties, where `n == streams.count`; document the linear string transformation for `language`.
- **Impact:** Repeated property access can rescan and allocate arrays, a cost that is invisible at the call site.
- **Change risk:** **Nonbreaking**.
- **Verification:** implementation inspection at `MediaProbe.swift:6-24,54-56` and LSP references across all plan implementations.

## Concerns

### C1 — `MediaPlan` and `MediaProcessingPlan` may not distinguish authored and compiled plans clearly enough

- **Location:** `Sources/vid/Media/MediaPlan.swift:3-10` and `Sources/vid/Media/MediaProcessor.swift:3-6,37-41`.
- **Use:** `let processingPlan = try plan.makeProcessingPlan(...)` at `MediaProcessor.swift:37` and equivalent direct test calls.
- **Classification:** `CONCERN`.
- **Rule:** include every word needed to avoid ambiguity and use terminology consistently.
- **Evidence:** one type is a protocol implemented by user-intent plans, while the other is a concrete FFmpeg argument-and-sidecar result. The near-synonymous names make the compilation boundary difficult to state without reading implementations.
- **Candidate:** intent required. Possible semantic families include `MediaOperationPlan` plus `FFmpegExecutionPlan`, but the intended long-term abstraction boundary is not documented.
- **Impact:** Future plan implementations may store responsibilities on the wrong side of the conversion boundary.
- **Change risk:** **Unknown** until the abstraction contract is documented.
- **Verification:** declaration and call-site inspection; tests exercise generated arguments but do not define the architectural distinction.

### C2 — `MediaOutputOptions.policy()` may be a factory or a semantic conversion

- **Location:** `Sources/vid/CLI/CommandOptions.swift:34-45`.
- **Use:** `let outputPolicy = try output.policy()` in encode, repair, and subtitle commands; inline `output.policy()` in remux and single-subtitle commands.
- **Classification:** `CONCERN`.
- **Rule:** factory method base names begin with `make`; side-effect-free methods otherwise read as noun phrases.
- **Evidence:** the method validates command-option combinations, resolves an optional path, and constructs an `OutputPolicy`. The missing documentation leaves its intended category—factory or command-to-domain conversion—unstated.
- **Candidate:** `makeOutputPolicy()` for factory intent; retain a noun phrase only with documentation establishing conversion semantics.
- **Impact:** The present call is concise, but future callers lack a stated ownership and validation contract.
- **Change risk:** **Source-breaking** for a rename; behavior-preserving.
- **Verification:** implementation and seven LSP-resolved calls; no documentation supplies the missing semantic intent.

## Non-issues checked

### N1 — `MediaPlan` is correctly a noun protocol

- **Location:** `Sources/vid/Media/MediaPlan.swift:3`.
- **Use:** `struct EncodePlan: MediaPlan` and the `plan: some MediaPlan` parameter.
- **Classification:** `NON-ISSUE`.
- **Rule:** protocols describing what something is use nouns; capability protocols use `-able`, `-ible`, or `-ing`.
- **Evidence:** conformers are plans, not objects that merely have a planning capability. `MediaPlannable` would weaken the semantic claim.
- **Candidate:** none.
- **Impact:** Current conformance reads naturally.
- **Change risk:** none.
- **Verification:** all four conformers and the generic processor use were inspected.

### N2 — `makeProcessingPlan` follows factory naming and parameter-label rules

- **Location:** `MediaPlan.swift:6-10` and all conforming plan files.
- **Use:** `plan.makeProcessingPlan(input: input, output: output.temporaryURL, probe: probe)`.
- **Classification:** `NON-ISSUE`.
- **Rule:** factory methods begin with `make`; arguments with distinct roles are labeled.
- **Evidence:** the method constructs a new `MediaProcessingPlan`, begins with `make`, and labels all three distinct URL/probe roles.
- **Candidate:** none.
- **Impact:** The call states construction and inputs clearly.
- **Change risk:** none.
- **Verification:** protocol, four implementations, processor call, and plan tests were inspected.

### N3 — Side-effecting transaction and append operations use imperative verbs

- **Location:** `OutputTransaction.swift:69,86`; `FFmpegPlanSupport.swift:44,59,73`; private transaction equivalents were inspected but remain out of scope.
- **Use:** `output.commit()`, `output.discardTemporaryOutput()`, and `appendMaps(..., to: &arguments)`.
- **Classification:** `NON-ISSUE`.
- **Rule:** side-effecting methods read as imperative verb phrases.
- **Evidence:** the methods mutate the filesystem or an `inout` argument, and their base names state those actions.
- **Candidate:** none.
- **Impact:** Mutation is visible at the point of use.
- **Change risk:** none.
- **Verification:** implementation and representative calls were inspected.

### N4 — Media terminology and casing follow established domain usage

- **Location:** `FFmpegPlanSupport`, `ffmpegArguments`, `HEVC`, `H.264`, `AAC`, `EAC3`, `CRF`, `hvc1`, and `remux` declarations and help text.
- **Use:** generated CLI help and FFmpeg argument construction.
- **Classification:** `NON-ISSUE`.
- **Rule:** use terms of art with established meaning; embrace established domain precedent; case acronyms consistently.
- **Evidence:** these spellings match FFmpeg, codec, and media-container terminology. Expanding or respelling them would reduce precision for the intended caller.
- **Candidate:** none.
- **Impact:** Domain experts see conventional vocabulary.
- **Change risk:** none.
- **Verification:** CLI help and all plan argument builders were inspected.

### N5 — Boolean `isBitmapSubtitle` already reads as an assertion

- **Location:** `Sources/vid/Media/MediaProbe.swift:46`.
- **Use:** `subtitleStreams.filter(\.isBitmapSubtitle)` and its negated text-subtitle counterpart.
- **Classification:** `NON-ISSUE`.
- **Rule:** Boolean methods and properties read as assertions.
- **Evidence:** the property forms a direct assertion about each stream and reads fluently as a key path.
- **Candidate:** none.
- **Impact:** Stream filtering is self-explanatory.
- **Change risk:** none.
- **Verification:** declaration and both filtering uses were inspected.

### N6 — Defaults, overloads, tuples, and closure API types introduce no guideline conflict

- **Location:** `MediaProcessor.init(runner:)`, `MediaProcessor.process(_:outputPolicy:plan:probe:)`, and the remaining production signatures.
- **Use:** `MediaProcessor()` and processor calls that omit the final `probe:` argument.
- **Classification:** `NON-ISSUE`.
- **Rule:** place defaulted parameters toward the end; do not overload only on return type; label tuple members and closure parameters in API types.
- **Evidence:** defaulted parameters are last or sole parameters. Production code defines no overload set, tuple API, or closure parameter type.
- **Candidate:** none.
- **Impact:** Calls have no default-argument ordering or compound-type ambiguity.
- **Change risk:** none.
- **Verification:** complete production declaration inventory.

### N7 — Argument Parser requirement names should remain unchanged

- **Location:** command `configuration`, `validate()`, and `run()` declarations throughout `Sources/vid`.
- **Use:** generated `vid --help`, validation, and command dispatch.
- **Classification:** `NON-ISSUE`.
- **Rule:** use established ecosystem terminology and satisfy protocol requirements without inventing parallel vocabulary.
- **Evidence:** these names are requirements or conventions of Swift Argument Parser. Renaming them would break conformance rather than improve this application’s API.
- **Candidate:** none.
- **Impact:** The command layer remains idiomatic to its framework.
- **Change risk:** none.
- **Verification:** conformances compile, generated help runs, and command declarations were inspected.

## Tooling limits

- Build, tests, formatter lint, and generated help do not judge semantic naming, grammar, or documentation completeness.
- The executable target exports no public library interface, so symbol graphs and API digester output would not represent the requested internal scope.
- LSP references establish the observed callers only; future call sites and downstream source compatibility do not exist as a declared package contract.
- The test suite covers five behavioral contracts, not every error case, flag combination, or subprocess failure mode.
- Synthesized memberwise initializers were assessed through observed calls; they do not have separately written declarations to document.

## Verdict

**NONCONFORMING** — 7 confirmed `VIOLATION` findings and 2 `DOCUMENTATION GAP` findings apply to the complete internal production scope. Two additional semantic naming questions remain `CONCERN`s. The highest-impact work is to document the internal API, make Boolean state assertive, clarify filename-suffix semantics, label weak path strings, and align helper names with their verified behavior.

This is a report-only review. No production declaration or call site was changed.
