# ``FFmpeg``

Execute authored FFmpeg argument arrays with replaceable process execution.

`FFmpegRunner` supports terminal-attached execution and `-progress` parsing.
The module deliberately does not decide codecs, streams, output paths, or
transaction behavior.

```swift
import FFmpeg

let runner = FFmpegRunner()
try await runner.run(arguments: [
    "-hide_banner", "-i", inputPath, "-c", "copy", outputPath,
])
```

Inject any `FFmpegRunning` implementation into higher-level processing code.
`FFmpegRunner` itself accepts a `CommandRunning` implementation from the
`CommandExecution` product.

## Topics

### Execution

- ``FFmpegRunning``
- ``FFmpegRunner``
