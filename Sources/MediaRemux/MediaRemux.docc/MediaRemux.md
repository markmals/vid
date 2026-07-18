# ``MediaRemux``

Repackage media as MP4 without re-encoding video.

The plan can copy or encode audio, keep or extract subtitles, and apply the HEVC
and Dolby tags used by Apple playback software.

```swift
import MediaProcessing
import MediaRemux

let plan = RemuxPlan(
    outputFilenameSuffix: "remuxed",
    settings: RemuxSettings(
        isAppleCompatible: true,
        audioEncoding: .copy,
        subtitleHandling: .extractBitmap
    )
)
```

`RemuxPlan` is pure plan construction. Use it with `MediaProcessor` for probing,
staged execution, and commit behavior.

## Topics

### Remuxing

- ``RemuxPlan``
- ``RemuxSettings``
