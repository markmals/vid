import CommandExecution

/// Executes FFmpeg argument arrays, with optional machine-readable progress.
public protocol FFmpegRunning: Sendable {
    /// Runs FFmpeg with output attached to the current terminal.
    func run(arguments: [String]) async throws

    /// Runs FFmpeg and reports completion fractions.
    ///
    /// Conforming implementations report values in the closed range `0...1`.
    /// A successful run reports `0` before work begins and ends with `1`.
    /// Intermediate values may be omitted when duration is unavailable, and
    /// implementations may report the same fraction more than once.
    func run(
        arguments: [String],
        durationSeconds: Double?,
        onProgress: @escaping @Sendable (_ fraction: Double) async -> Void
    ) async throws
}

/// An FFmpeg executor backed by a replaceable command runner.
public struct FFmpegRunner: FFmpegRunning {
    private let commandRunner: any CommandRunning

    /// Creates an FFmpeg runner.
    /// - Parameter commandRunner: The command runner used to invoke `ffmpeg`.
    public init(commandRunner: any CommandRunning = ToolRunner()) {
        self.commandRunner = commandRunner
    }

    /// Runs FFmpeg with output attached to the current terminal.
    public func run(arguments: [String]) async throws {
        try await commandRunner.streamOutput(of: "ffmpeg", arguments: arguments)
    }

    /// Runs FFmpeg while decoding its `-progress` output.
    public func run(
        arguments: [String],
        durationSeconds: Double?,
        onProgress: @escaping @Sendable (_ fraction: Double) async -> Void
    ) async throws {
        let progressArguments = ["-progress", "pipe:1", "-nostats"] + arguments
        await onProgress(0)
        try await commandRunner.streamLines(
            of: "ffmpeg",
            arguments: progressArguments
        ) { line in
            guard
                let fraction = Self.progressFraction(
                    line: line,
                    durationSeconds: durationSeconds
                )
            else {
                return
            }
            await onProgress(fraction)
        }
        await onProgress(1)
    }

    private static func progressFraction(
        line: String,
        durationSeconds: Double?
    ) -> Double? {
        if line == "progress=end" {
            return 1
        }
        guard line.hasPrefix("out_time_us="),
            let durationSeconds,
            let microseconds = Double(line.dropFirst("out_time_us=".count))
        else {
            return nil
        }
        return min(max(microseconds / 1_000_000 / durationSeconds, 0), 1)
    }
}
