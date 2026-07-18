# ``MediaEncoding``

Author HEVC encoding plans for Apple-compatible MP4 output.

`EncodePlan` re-encodes video with libx265, applies `hvc1`, maps selected audio
and text subtitles, and can extract bitmap subtitles through the shared
processing transaction.

```swift
import MediaEncoding
import MediaProcessing

let plan = EncodePlan(
    settings: EncodeSettings(
        audioEncoding: .eac3(bitrate: "320k"),
        crf: 23,
        excludedAudioLanguages: [],
        shouldNormalizeDispositions: true,
        preset: "medium",
        subtitleHandling: .extractBitmap
    )
)
```

Pass the plan to `MediaProcessor`, or call `makeExecutionPlan` with already
probed metadata when only pure argument construction is needed.

## Topics

### Encoding

- ``EncodePlan``
- ``EncodeSettings``
