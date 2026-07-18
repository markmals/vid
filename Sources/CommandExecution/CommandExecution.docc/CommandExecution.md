# ``CommandExecution``

Run external commands through small, replaceable capabilities.

`ToolRunner` locates executables through `PATH` or explicit overrides. Use
`CommandOutputCapturing`, `CommandOutputStreaming`, or `CommandLineStreaming`
when a consumer needs only one execution style; use `CommandRunning` when it
needs all three.

```swift
import CommandExecution

let runner = ToolRunner()
let version = try await runner.captureOutput(
    of: "ffmpeg",
    arguments: ["-version"]
)
```

The module depends only on Swift Subprocess. It has no media-specific behavior.
Non-zero exits throw `CommandExecutionError`.

## Topics

### Capabilities

- ``CommandOutputCapturing``
- ``CommandOutputStreaming``
- ``CommandLineStreaming``
- ``CommandRunning``

### Implementation

- ``ToolRunner``
- ``CommandExecutionError``
