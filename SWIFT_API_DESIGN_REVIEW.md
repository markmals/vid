# SWIFT API DESIGN REVIEW — `vid` modular library products

## Scope

- **Reviewed change:** commit `9e0b493` (`Split media foundation into composable libraries`).
- **Modules and access levels:** every `public` declaration in `CommandExecution`, `FFmpeg`, `FFprobe`, `MediaDiscovery`, `MediaProcessing`, `MediaConversion`, `MediaEncoding`, `MediaRemux`, `MediaRepair`, and `MediaSubtitles`. No `open` or `package` declarations exist in these targets. Internal declarations in the `vid` executable are outside this review.
- **Inventory:** 206 source-located public symbols: `CommandExecution` 18, `FFmpeg` 7, `FFprobe` 43, `MediaDiscovery` 10, `MediaProcessing` 59, `MediaConversion` 35, `MediaEncoding` 13, `MediaRemux` 10, `MediaRepair` 4, and `MediaSubtitles` 7.
- **Documentation:** declaration comments and all ten target-level DocC catalogs. The catalogs contain standalone imports and representative calls.
- **Use sites:** the `vid` executable, unit tests, integration tests, and DocC examples. Minimal calls are used only where they expose grammar more directly than an existing expression.
- **Guidelines source:** [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) through `.agents/skills/reviewing-swift-api-design/REFERENCE.md`.
- **Domain precedent:** `FFmpeg`, `ffmpeg`, `ffprobe`, H.264, H.265, HEVC, AAC, E-AC-3, CRF, SDH, SRT, codec tags, and stream dispositions are treated as established media-domain terms. `URL` follows Foundation casing.

## Baseline

- `swift package dump-symbol-graph --minimum-access-level public` — **PASS**. Emitted symbol graphs for all ten library targets; useful for the 206-symbol inventory, not semantic clarity.
- `mise run build` — **PASS** at the reviewed HEAD. Establishes that declarations type-check, not that calls are fluent.
- `mise run lint` — **PASS**. Establishes configured formatting only.
- `mise run docs` — **PASS** for all ten archives with warnings treated as errors. Establishes symbol extraction and valid DocC markup, not prose accuracy or completeness.
- `mise run test` — **PASS**, 46 tests in 15 suites. Establishes only covered behavior.
- `mise run test:integration` — **PASS**, 6 tests in 1 suite against real FFmpeg and ffprobe.
- `swift test` — **FAIL**, 17 integration-test issues when unit and integration targets run together. The integration probe observed the unit fixture's fake media-tool output. **[INFERENCE]** The evidence is consistent with process-wide `PATH` interference from concurrently running test targets. This does not establish an API-design defect; the repository's isolated test tasks pass.

## Violations

### V1 — Raw integer disposition flags have Boolean-assertion names

- **Classification:** `VIOLATION`
- **Location:** `Sources/FFprobe/MediaProbe.swift:71-90`, `MediaStream.Disposition.attachedPicture`, `isDefault`, `isForced`, `isHearingImpaired`, and their initializer parameters.
- **Use:** `stream.disposition?.isForced == 1` and `stream.disposition?.isDefault == 1` in `Sources/MediaConversion/ConversionSubtitleSelection.swift:124-130`; cover-art filtering uses `$0.disposition?.attachedPicture != 1` in `Sources/FFprobe/MediaProbe.swift:53`.
- **Rule:** **Promote clear usage** — compensate for weak types such as `Int` with a role noun; **Strive for fluent usage** — Boolean methods and properties read as assertions, while other properties read as nouns.
- **Evidence:** the three `is…` properties look and are documented like Boolean assertions but return `Int?`, so they cannot be used as assertions. `attachedPicture` also fails to identify whether its integer is a count, index, or raw flag. Every production use compares the values to `1`, proving raw-flag semantics.
- **Candidate:** preserve the raw representation while naming its role: `attachedPictureFlag: Int?`, `defaultFlag: Int?`, `forcedFlag: Int?`, and `hearingImpairedFlag: Int?`, including matching initializer labels and unchanged coding keys. A conversion to `Bool` requires a separate decision about absent versus false values and is not presumed here.
- **Impact:** callers can reasonably write or expect `if disposition.isForced`, but the API instead requires an undocumented integer comparison.
- **Change risk:** source-breaking; the representation-preserving candidate need not affect decoding behavior.
- **Verification:** inspected decoding keys, initializer assignment, first-video selection, and subtitle-role selection.

### V2 — `highQuality(videoCodec:)` is a factory without a `make` base name

- **Classification:** `VIOLATION`
- **Location:** `Sources/MediaConversion/ConversionVideoCodec.swift:25-28`, `MediaConversionSettings.highQuality(videoCodec:)`.
- **Use:** `MediaConversionSettings.highQuality(videoCodec: videoCodec)` in `Sources/MediaConversion/MediaConverter.swift:44` and `.highQuality(videoCodec: codec)` in `Tests/VidTests/ConversionTestSupport.swift:66`.
- **Rule:** **Strive for fluent usage** — factory method base names begin with `make`.
- **Evidence:** the implementation constructs and returns a new `Self` with fixed CRF and preset values. Its documentation calls those values defaults, establishing construction rather than a query on shared state.
- **Candidate:** `public static func makeHighQuality(videoCodec: ConversionVideoCodec) -> Self`.
- **Impact:** the present call reads like a quality classification or query rather than construction of settings.
- **Change risk:** source-breaking rename.
- **Verification:** inspected the implementation and both production and test calls.

### V3 — `inputArguments(_:)` omits the prepositional role of its first argument

- **Classification:** `VIOLATION`
- **Location:** `Sources/MediaProcessing/FFmpegPlanSupport.swift:10-25`, `FFmpegPlanSupport.inputArguments(_:)`.
- **Use:** `FFmpegPlanSupport.inputArguments(input)` in `Sources/MediaConversion/ConversionPlan.swift:36`, `Sources/MediaEncoding/EncodePlan.swift:52`, `Sources/MediaRemux/RemuxPlan.swift:48`, `Sources/MediaRepair/RepairPlan.swift:37`, and `Sources/MediaSubtitles/AddSubtitlePlan.swift:51`.
- **Rule:** **Argument labels** — when the first argument forms a prepositional phrase, begin its label at the preposition; functions should form grammatical English at use sites.
- **Evidence:** the documentation defines the result as arguments **for** reading `input`. `inputArguments(input)` does not form a grammatical noun phrase and can be read as repeated type information.
- **Candidate:** `public static func inputArguments(for input: URL) -> [String]`.
- **Impact:** callers must infer that the unlabeled URL is the source for which arguments are being produced.
- **Change risk:** source-breaking label change.
- **Verification:** inspected the implementation, its documentation, six production calls, and the focused helper test at `Tests/VidTests/FFmpegPlanSupportTests.swift:12`.

### V4 — `convert(path:videoCodec:)` retains a redundant first label

- **Classification:** `VIOLATION`
- **Location:** `Sources/MediaConversion/MediaConverter.swift:31-35`, `MediaConverter.convert(path:videoCodec:)`.
- **Use:** `converter.convert(path: library.path, videoCodec: .h265)` in `Tests/VidTests/MediaConverterTests.swift:42`; the DocC example repeats the same form at `Sources/MediaConversion/MediaConversion.docc/MediaConversion.md:15-18`.
- **Rule:** **Argument labels** — if the first argument forms a correct grammatical phrase with the base name, omit its label and move only preceding words into the base name.
- **Evidence:** “convert path” is the operation, so `converter.convert(library.path, videoCodec: .h265)` is grammatical. The current `convert(path: library.path, …)` repeats the role already supplied by the argument expression and parameter name.
- **Candidate:** `public func convert(_ path: String, videoCodec: ConversionVideoCodec) async throws -> [URL]`.
- **Impact:** the current point of use is less fluent without adding distinguishing information.
- **Change risk:** source-breaking label change.
- **Verification:** inspected the implementation, CLI call, DocC example, and success/failure test calls.

### V5 — Public closure types omit their parameter names

- **Classification:** `VIOLATION`
- **Location:**
  - `Sources/CommandExecution/ToolRunner.swift:25-29,119-123`, `onStandardOutputLine: @Sendable (String) async -> Void`;
  - `Sources/FFmpeg/FFmpegRunner.swift:9-13,32-36`, `onProgress: @Sendable (Double) async -> Void`;
  - `Sources/MediaProcessing/MediaProcessor.swift:38-45`, `progress: @Sendable (Double) async -> Void`;
  - `Sources/MediaConversion/MediaConverter.swift:21-25`, `reportProgress: @Sendable (MediaConversionProgress) async -> Void`.
- **Use:** implementations immediately recover the missing roles as `{ line in … }` (`FFmpegRunner.swift:42`) and `{ fraction in … }` (`MediaConverter.swift:63`); the CLI supplies `{ progress in … }` at `Sources/vid/Convert/ConvertCommand.swift:23-25`.
- **Rule:** **Compound API** — name closure parameters in API types; **Promote clear usage** — compensate for weak `String` and `Double` types with role names.
- **Evidence:** each callback's semantic parameter name is known and stable in the implementation, but absent from the exported function type.
- **Candidate:** use `(_ line: String)`, `(_ fraction: Double)`, and `(_ progress: MediaConversionProgress)` in the corresponding closure types.
- **Impact:** generated interfaces and documentation do not tell conformers or callers what the callback value represents; the `Double` callbacks especially omit their unit and role.
- **Change risk:** nonbreaking for call syntax and behavior.
- **Verification:** inspected protocol requirements, conforming implementations, callback forwarding, CLI consumption, and public symbol declarations.

## Documentation gaps

### D1 — Two public declarations have no source documentation comment

- **Classification:** `DOCUMENTATION GAP`
- **Location:** `Sources/MediaProcessing/SubtitleExtraction.swift:11`, `SubtitleSidecarEncoding.ffmpegCodecName`; `Sources/MediaConversion/ConversionSubtitle.swift:14`, `ConversionSubtitleRole.<(_:_:)`.
- **Use:** `extraction.encoding.ffmpegCodecName` selects an FFmpeg codec at `Sources/MediaProcessing/MediaProcessor.swift:107`; subtitle selection compares `lhs.element.role < rhs.element.role` at `Sources/MediaConversion/ConversionSubtitleSelection.swift:32`.
- **Rule:** **Fundamentals and documentation** — write a documentation comment for every declaration in scope and begin with a summary.
- **Evidence:** both `public` declaration lines lack a preceding `///` comment. The comparison's implicit raw-value order is semantically important: forced, default, SDH, then unspecified.
- **Candidate:** document `ffmpegCodecName` as the FFmpeg codec token for the sidecar encoding; document `<` as comparing subtitle-selection priority and state which direction has higher priority.
- **Impact:** callers cannot discover the codec-token contract or the meaning of the public ordering operation from source documentation.
- **Change risk:** nonbreaking documentation-only change.
- **Verification:** direct source scan of every public declaration. The symbol graph inherited documentation for `<`, demonstrating why symbol-graph documentation counts alone are insufficient.

### D2 — Nonconstant-time computed properties omit complexity documentation

- **Classification:** `DOCUMENTATION GAP`
- **Location:**
  - `Sources/CommandExecution/CommandExecutionError.swift:20`, `errorDescription`;
  - `Sources/FFprobe/MediaProbe.swift:30,35,40,52,57,62`, `audioStreams`, `bitmapSubtitleStreams`, `durationSeconds`, `firstVideoStream`, `subtitleStreams`, `textSubtitleStreams`;
  - `Sources/FFprobe/MediaProbe.swift:158`, `MediaStream.language`;
  - `Sources/FFprobe/MediaProbeError.swift:9`, `errorDescription`;
  - `Sources/MediaDiscovery/MediaDiscoveryError.swift:11`, `errorDescription`;
  - `Sources/MediaProcessing/MediaProcessingError.swift:17`, `errorDescription`.
- **Use:** `probe.audioStreams`, `probe.subtitleStreams`, and the filtered variants are repeatedly traversed in `Tests/VidTests/MediaProbeTests.swift:28-33` and production plan builders; user-facing tests evaluate every `errorDescription` at `Tests/VidTests/ToolRunnerTests.swift:100-123`.
- **Rule:** **General conventions** — document the complexity of every computed property that is not $O(1)$.
- **Evidence:** the stream properties call `filter` or `first` over `streams`; `durationSeconds` parses a string; `language` lowercases a string; error descriptions construct strings proportional to associated text. No reviewed source contains a `Complexity` documentation section.
- **Candidate:** add `- Complexity:` clauses, including $O(n)$ in stream count for the stream queries and input-length-based costs for parsing, lowercasing, and error-string construction.
- **Impact:** callers may accidentally repeat full stream scans in loops or assume property access is constant time.
- **Change risk:** nonbreaking documentation-only change.
- **Verification:** inspected every computed property body and searched all reviewed source for complexity documentation.

### D3 — Disposition comments describe Boolean meaning without raw-value semantics

- **Classification:** `DOCUMENTATION GAP`
- **Location:** `Sources/FFprobe/MediaProbe.swift:69-90`, `MediaStream.Disposition` properties and initializer.
- **Use:** `stream.disposition?.isHearingImpaired == 1` at `Sources/MediaConversion/ConversionSubtitleSelection.swift:130`.
- **Rule:** **Fundamentals and documentation** — describe what a declaration is; **Promote clear usage** — weak types require role information.
- **Evidence:** each comment starts with “Whether,” but the declaration is `Int?`. The documentation does not state that `1` means enabled, `0` means disabled, and `nil` means the field was absent.
- **Candidate:** pending the V1 representation decision, explicitly document the raw ffprobe flag domain and absence semantics.
- **Impact:** callers cannot safely distinguish false, absent, and unexpected integer values from the API documentation.
- **Change risk:** nonbreaking documentation change; a later type conversion would be behavior-affecting and source-breaking.
- **Verification:** inspected decoded coding keys and all production comparisons.

### D4 — `MediaConverter.convert` omits its destructive and return contract

- **Classification:** `DOCUMENTATION GAP`
- **Location:** `Sources/MediaConversion/MediaConverter.swift:31-35`, plus the module example at `Sources/MediaConversion/MediaConversion.docc/MediaConversion.md:3-23`.
- **Use:** after `converter.convert(path: input.path, videoCodec: .h265)`, the test asserts that the source no longer exists at `Tests/VidTests/MediaConverterTests.swift:111-114`; recursive conversion similarly removes AVI and MOV sources at lines 42-49.
- **Rule:** **Fundamentals and documentation** — describe what a function does and returns, including salient side effects and errors.
- **Evidence:** the method comment says only that it converts a file or directory. The implementation always uses recursive discovery and `shouldReplaceInput: true`, discovers matching sidecars, returns final output URLs, and can throw discovery, destination-collision, probing, FFmpeg, and transaction errors.
- **Candidate:** document recursive discovery, successful source replacement, subtitle-sidecar behavior, the returned final URLs, progress behavior, and error categories.
- **Impact:** a library caller can invoke an apparently ordinary conversion without learning at the method declaration that successful completion removes or replaces inputs.
- **Change risk:** nonbreaking documentation-only change.
- **Verification:** inspected the output policy and success/failure tests.

### D5 — `MediaProcessor.process` does not document most of its public contract

- **Classification:** `DOCUMENTATION GAP`
- **Location:** `Sources/MediaProcessing/MediaProcessor.swift:37-45`, `process(_:outputPolicy:plan:probe:temporaryDirectoryRoot:progress:)`.
- **Use:** `MediaConverter` passes a plan, temporary root, and fraction callback at `Sources/MediaConversion/MediaConverter.swift:58-65`; feature commands also rely on the returned final URL and transactional replacement.
- **Rule:** **Fundamentals and documentation** — describe what a function does and returns and use recognized parameter, return, and throws documentation.
- **Evidence:** the one-line comment mentions staging but does not describe the optional supplied probe, temporary-directory ownership, callback value, returned URL, terminal output, or the errors propagated from probing, planning, FFmpeg, sidecar extraction, and commit.
- **Candidate:** add `- Parameters:`, `- Returns:`, and `- Throws:` sections, including that progress is a completion fraction and that the method prints processing/creation messages.
- **Impact:** this is the central composition API, yet independent callers and alternate plan authors cannot recover its complete operational contract from the declaration.
- **Change risk:** nonbreaking documentation-only change.
- **Verification:** inspected the complete implementation and representative calls from conversion and feature workflows.

### D6 — `discardTemporaryOutput()` promises deletion but suppresses deletion failures

- **Classification:** `DOCUMENTATION GAP`
- **Location:** `Sources/MediaProcessing/OutputTransaction.swift:150-156`, `OutputTransaction.discardTemporaryOutput()`.
- **Use:** cleanup calls it without error handling after rollback at `Sources/MediaProcessing/MediaProcessor.swift:91`; tests call it twice at `Tests/VidTests/FilesystemTests.swift:136-138`.
- **Rule:** **Fundamentals and documentation** — accurately describe what a function does.
- **Evidence:** the summary says “Deletes,” but the implementation uses `try?` and returns no status, so a filesystem error can leave the workspace in place without informing the caller.
- **Candidate:** document the operation as best-effort and state that removal errors are ignored, or establish a throwing contract if failure must be observable.
- **Impact:** callers may rely on cleanup that the API neither guarantees nor reports.
- **Change risk:** documentation clarification is nonbreaking; making the method throwing is source-breaking and behavior-affecting.
- **Verification:** inspected implementation, rollback use, and idempotence test.

## Concerns

### C1 — Progress protocols do not establish cross-implementation invariants

- **Classification:** `CONCERN`
- **Location:** `Sources/FFmpeg/FFmpegRunner.swift:4-13`, `FFmpegRunning.run(arguments:durationSeconds:onProgress:)`; forwarded by `Sources/MediaProcessing/MediaProcessor.swift:38-45` and `Sources/MediaConversion/MediaConverter.swift:21-24`.
- **Use:** `TerminalConversionProgressReporter` treats `fraction >= 1` as completion at `Sources/vid/Convert/ConversionProgressBar.swift:10-20`.
- **Rule:** **Fundamentals and documentation** — protocol requirements must describe what conformers do; **Compound API** — closure roles and contracts must be clear.
- **Evidence:** the concrete runner emits `0`, parsed fractions, and `1`, but the protocol does not state whether conformers must emit endpoints, remain monotonic, clamp values, avoid duplicates, or invoke the callback when duration is absent.
- **Candidate:** intent required before prescribing exact invariants; then document them on the protocol requirement and forwarding APIs.
- **Impact:** replaceable conformers can satisfy the type while producing progress sequences that break existing UI assumptions.
- **Change risk:** unknown; documentation is nonbreaking, but enforcing newly stated behavior may affect conformers.
- **Verification:** compared the protocol requirement, concrete implementation, forwarding layers, tests, and terminal consumer.

### C2 — The public transaction contract claims atomic promotion across caller-selected temporary roots

- **Classification:** `CONCERN`
- **Location:** `Sources/MediaProcessing/OutputTransaction.swift:31-55`, type documentation and `init(sourceURL:outputFilenameSuffix:policy:temporaryDirectoryRoot:)`.
- **Use:** tests and `MediaConverter` supply custom temporary roots (`Tests/VidTests/MediaConverterTests.swift:36-40`), while `commit()` promotes with `FileManager.moveItem` or `replaceItemAt` at `OutputTransaction.swift:121-144`.
- **Rule:** **Fundamentals and documentation** — documentation must accurately describe behavior and preconditions.
- **Evidence:** the type promises atomic promotion, but the API permits a temporary root on a different filesystem. The reviewed tests use one temporary hierarchy and do not establish cross-filesystem semantics.
- **Candidate:** intent and a cross-filesystem experiment are required. Depending on the result, constrain temporary storage to the destination filesystem or qualify the atomicity claim.
- **Impact:** callers may rely on a crash-safety guarantee that is not demonstrated for every accepted argument.
- **Change risk:** unknown; documentation qualification is nonbreaking, while storage constraints or implementation changes may affect behavior.
- **Verification:** inspected initializer freedom, commit operations, and test topology; no cross-filesystem runtime check was present.

## Non-issues checked

### N1 — Capability protocol names use the prescribed suffixes

- **Classification:** `NON-ISSUE`
- **Location:** `CommandOutputCapturing`, `CommandOutputStreaming`, `CommandLineStreaming`, `CommandRunning`, `FFmpegRunning`, and `MediaProbing`.
- **Use:** `mediaProcessor(runner: any CommandRunning)` composes `MediaProber` and `FFmpegRunner` at `Tests/VidTests/TestSupport.swift:77-81`.
- **Rule:** **Strive for fluent usage** — capability protocols use `-able`, `-ible`, or `-ing`.
- **Evidence:** each protocol describes a capability and uses `-ing`; `CommandRunning` composes three narrower capabilities without changing their meanings.
- **Candidate:** none.
- **Impact:** none; names communicate roles at generic and existential use sites.
- **Change risk:** none.
- **Verification:** inspected declarations, conformances, and injected use.

### N2 — Actual Boolean properties read as assertions

- **Classification:** `NON-ISSUE`
- **Location:** `OutputPolicy.shouldOverwriteExistingOutput`, `shouldRemoveSource`, `shouldReplaceInput`; `RemuxSettings.isAppleCompatible`; `EncodeSettings.shouldNormalizeDispositions`; `MediaStream.isBitmapSubtitle`.
- **Use:** `if settings.isAppleCompatible` at `Sources/MediaRemux/RemuxPlan.swift:60` and `if settings.shouldNormalizeDispositions` at `Sources/MediaEncoding/EncodePlan.swift:74`.
- **Rule:** **Strive for fluent usage** — Boolean properties read as assertions.
- **Evidence:** these properties return `Bool` and form grammatical conditions. They are distinct from the raw integer disposition flags in V1.
- **Candidate:** none.
- **Impact:** none.
- **Change risk:** none.
- **Verification:** inspected declarations and conditions.

### N3 — `makeExecutionPlan` follows factory and grammar rules

- **Classification:** `NON-ISSUE`
- **Location:** `MediaOperationPlan.makeExecutionPlan(input:output:probe:)` and conforming plan types.
- **Use:** `plan.makeExecutionPlan(input: input, output: output.temporaryURL, probe: probe)` at `Sources/MediaProcessing/MediaProcessor.swift:61-65`.
- **Rule:** **Strive for fluent usage** — factories begin with `make`; initializer and factory arguments do not continue the base-name phrase.
- **Evidence:** the method creates a new `FFmpegExecutionPlan`, begins with `make`, and labels each role-bearing argument.
- **Candidate:** none.
- **Impact:** none.
- **Change risk:** none.
- **Verification:** inspected protocol semantics, conformers, and execution call.

### N4 — FFmpeg `run` overloads preserve one operation and are not return-type-only

- **Classification:** `NON-ISSUE`
- **Location:** `Sources/FFmpeg/FFmpegRunner.swift:6-13`, `FFmpegRunning.run` overloads.
- **Use:** sidecar extraction calls `runner.run(arguments: arguments)` at `Sources/MediaProcessing/MediaProcessor.swift:110`; the main output supplies duration and progress at lines 78-82.
- **Rule:** **General conventions** — overloads may share a base name for the same meaning or distinct domains and must not differ only by return type.
- **Evidence:** both overloads execute FFmpeg; the second adds duration-aware progress parameters. Both return `Void` and differ by labeled arguments.
- **Candidate:** none.
- **Impact:** none.
- **Change risk:** none.
- **Verification:** inspected both requirements, implementations, and calls.

### N5 — Media abbreviations and weak string fields have established or explicit roles

- **Classification:** `NON-ISSUE`
- **Location:** `ConversionVideoCodec.h264/h265`, `MediaConversionSettings.crf`, `AudioEncoding.aac/eac3`, `SubtitleSidecarEncoding.srt`, `MediaStream.codecName/codecTagString/codecType`, and bitrate/language/preset fields.
- **Use:** `MediaConversionSettings(videoCodec: .h265, crf: 18, preset: "veryslow")` is a representative construction; FFmpeg argument builders pass the values to their corresponding domain options.
- **Rule:** **Use terminology well** and **Promote clear usage** — established domain terms are acceptable; weak types need role nouns.
- **Evidence:** the abbreviations are standard media/FFmpeg terms, and every `String` or `Int` field identifies its role (`bitrate`, `language`, `preset`, `codecName`, `crf`).
- **Candidate:** none.
- **Impact:** none; replacing these terms with expanded non-domain wording would reduce precision.
- **Change risk:** none.
- **Verification:** inspected documentation and FFmpeg/ffprobe serialization sites.

### N6 — Defaulted parameters follow required parameters

- **Classification:** `NON-ISSUE`
- **Location:** public initializers and methods with defaults, including `ToolRunner.init`, `MediaProbe.init`, `InputDiscovery.mediaFiles`, `MediaProcessor.process`, `OutputTransaction.init`, and `MediaConverter.init`.
- **Use:** `MediaConverter(processor: …, temporaryDirectoryRoot: …)` omits only the trailing progress callback at `Tests/VidTests/MediaConverterTests.swift:77-80`.
- **Rule:** **Parameters** — put defaulted parameters toward the end and use defaults for a single common value.
- **Evidence:** required parameters precede defaults; defaulted arguments are labeled; no repetitive overload family substitutes for one common default.
- **Candidate:** none.
- **Impact:** none.
- **Change risk:** none.
- **Verification:** inspected all exported declaration fragments in the symbol graphs and source.

### N7 — Stateless helper namespaces do not displace a natural instance

- **Classification:** `NON-ISSUE`
- **Location:** `FFmpegPlanSupport` and `FilePathResolver` uninstantiable enums.
- **Use:** `FFmpegPlanSupport.appendMaps(video:audio:subtitles:to:)` and `FilePathResolver.resolvedURL(for:)` operate only on supplied values.
- **Rule:** **General conventions** — prefer members unless no natural `self` exists.
- **Evidence:** both namespaces are stateless, expose no instances, and group operations around a coherent domain where no supplied argument is the natural owner of the entire operation.
- **Candidate:** none.
- **Impact:** none.
- **Change risk:** none.
- **Verification:** inspected every public helper implementation; no public free functions were introduced.

## Tooling limits

- Compilation, formatting, tests, and DocC do not establish naming clarity, grammatical calls, accurate prose, or complete protocol semantics.
- Symbol graphs can attach inherited documentation to a declaration without an explicit source comment; this occurred for `ConversionSubtitleRole.<`.
- SourceKit-LSP returned no references for known cross-target calls to `highQuality` and `convert`; call sites were therefore confirmed by exact source search and manual inspection.
- Tests cover current concrete implementations, not every alternate implementation permitted by the new protocols.
- No cross-filesystem transaction experiment was available, so C2 remains a concern rather than a violation.
- Internal executable-only declarations were intentionally excluded; this verdict does not cover their naming or documentation.

## Verdict

**NONCONFORMING** — 5 confirmed `VIOLATION` findings and 6 confirmed `DOCUMENTATION GAP` findings across the reviewed 206-symbol public surface. Two additional issues remain `CONCERN`s because the intended progress invariants and cross-filesystem atomicity guarantee are not established. Seven suspicious patterns were checked and recorded as `NON-ISSUE`s.
