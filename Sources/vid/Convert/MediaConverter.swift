import Foundation

/// Progress emitted while converting one file or a recursive batch.
enum MediaConversionProgress: Equatable, Sendable {
    /// Progress through the current FFmpeg conversion, from zero through one.
    case file(URL, fraction: Double)
    /// Number of files successfully processed out of the discovered total.
    case batch(processed: Int, total: Int)
}

/// Discovers and safely replaces existing media with Apple-compatible MP4 files.
struct MediaConverter: Sendable {
    private let processor: MediaProcessor
    private let reportProgress: @Sendable (MediaConversionProgress) async -> Void

    /// Creates a converter with injectable process execution and progress reporting.
    init(
        runner: ToolRunner = ToolRunner(),
        reportProgress: @escaping @Sendable (MediaConversionProgress) async -> Void = { _ in },
    ) {
        processor = MediaProcessor(runner: runner)
        self.reportProgress = reportProgress
    }

    /// Converts one file or every supported file beneath a directory.
    func convert(
        path: String,
        videoCodec: ConversionVideoCodec,
    ) async throws -> [URL] {
        fatalError("Not Implemented")
    }
}
