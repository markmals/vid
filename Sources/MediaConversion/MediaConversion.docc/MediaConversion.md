# ``MediaConversion``

Convert files and recursive media-library inputs to Apple-compatible MP4 output.

The conversion policy copies already-compatible video, otherwise encodes H.264
or H.265, normalizes audio per stream, selects one text subtitle for embedding,
and stages the remaining subtitles as sidecars.

```swift
import MediaConversion

let converter = MediaConverter { progress in
    print(progress)
}
let outputs = try await converter.convert(
    "~/Media/Incoming",
    videoCodec: .h265
)
```

For caller-owned discovery or transactions, create a `ConversionPlan` directly
and pass it to `MediaProcessor`. `MediaConverter` accepts an injected processor,
temporary directory, and progress callback.

## Topics

### Conversion

- ``MediaConverter``
- ``MediaConversionProgress``
- ``ConversionPlan``
- ``ConversionVideoCodec``
- ``MediaConversionSettings``

### External subtitles

- ``ExternalSubtitle``
- ``ExternalSubtitleDiscovery``
- ``ConversionSubtitleRole``
