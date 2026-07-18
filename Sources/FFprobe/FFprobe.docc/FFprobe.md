# ``FFprobe``

Read typed stream and container metadata from ffprobe.

The probe accepts video, audio-only, and subtitle-only inputs. Consumers decide
which stream kinds their own operation requires.

```swift
import Foundation
import FFprobe

let metadata = try await MediaProber().probe(
    URL(fileURLWithPath: "/media/movie.mkv")
)
for stream in metadata.audioStreams {
    print(stream.codecName ?? "unknown")
}
```

`MediaProber` depends on the capture capability from `CommandExecution` and can
be replaced through `MediaProbing`. Invalid JSON throws `MediaProbeError`;
command failures remain `CommandExecutionError` values.

## Topics

### Metadata

- ``MediaProbe``
- ``MediaStream``

### Probing

- ``MediaProbing``
- ``MediaProber``
- ``MediaProbeError``
