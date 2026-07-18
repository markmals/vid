# ``MediaSubtitles``

Build a plan that adds one external text subtitle track to a video.

The plan copies video and audio, converts text subtitles to `mov_text`, extracts
bitmap subtitles as sidecars, and preserves Apple-compatible HEVC and audio tags.

```swift
import Foundation
import MediaSubtitles

let plan = AddSubtitlePlan(
    subtitle: URL(fileURLWithPath: "/media/Movie.en.srt"),
    language: "eng",
    title: "English"
)
```

`AddSubtitlePlan` only authors an execution plan. Use `MediaProcessor` when the
caller also needs probing, staged outputs, and rollback.

## Topics

### Adding subtitles

- ``AddSubtitlePlan``
