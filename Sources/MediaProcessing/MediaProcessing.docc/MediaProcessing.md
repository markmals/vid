# ``MediaProcessing``

Compose probe metadata, FFmpeg plans, and staged filesystem commits.

An operation implements `MediaOperationPlan`. `MediaProcessor` probes the input,
asks the operation for an `FFmpegExecutionPlan`, stages the main output and
subtitle sidecars, and commits only non-empty results.

```swift
import Foundation
import MediaProcessing

func process(
    _ input: URL,
    with plan: some MediaOperationPlan
) async throws -> URL {
    let policy = OutputPolicy(
        outputDirectory: nil,
        shouldOverwriteExistingOutput: false,
        shouldRemoveSource: false,
        shouldReplaceInput: false
    )
    return try await MediaProcessor().process(
        input,
        outputPolicy: policy,
        plan: plan
    )
}
```

Probe and FFmpeg execution are independently replaceable through `MediaProbing`
and `FFmpegRunning`. The module depends on the `FFprobe` and `FFmpeg` products;
it does not define a codec policy.

## Topics

### Operation contracts

- ``MediaOperationPlan``
- ``FFmpegExecutionPlan``
- ``SubtitleExtractionPlan``
- ``SubtitleSidecarEncoding``

### Processing

- ``MediaProcessor``
- ``OutputPolicy``
- ``OutputTransaction``
- ``MediaProcessingError``

### Plan building

- ``FFmpegPlanSupport``
- ``AudioEncoding``
- ``SubtitleHandling``
