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
    private let temporaryDirectoryRoot: URL

    /// Creates a converter with injectable process execution, temporary storage,
    /// and progress reporting.
    init(
        runner: ToolRunner = ToolRunner(),
        temporaryDirectoryRoot: URL = FileManager.default.temporaryDirectory,
        reportProgress: @escaping @Sendable (MediaConversionProgress) async -> Void = { _ in }
    ) {
        processor = MediaProcessor(runner: runner)
        self.temporaryDirectoryRoot = temporaryDirectoryRoot
        self.reportProgress = reportProgress
    }

    /// Converts one file or every supported file beneath a directory.
    func convert(
        path: String,
        videoCodec: ConversionVideoCodec
    ) async throws -> [URL] {
        let files = try InputDiscovery().mediaFiles(
            at: [path],
            recursive: true,
            supportedExtensions: Self.supportedExtensions
        )
        try validateUniqueDestinations(for: files)
        await reportProgress(.batch(processed: 0, total: files.count))

        let settings = MediaConversionSettings.highQuality(videoCodec: videoCodec)
        let outputPolicy = OutputPolicy(
            outputDirectory: nil,
            shouldOverwriteExistingOutput: true,
            shouldRemoveSource: false,
            shouldReplaceInput: true
        )
        let reportProgress = self.reportProgress
        var outputs: [URL] = []
        outputs.reserveCapacity(files.count)

        for (index, file) in files.enumerated() {
            let probe = try await processor.prober.probe(file)
            let subtitles = try ExternalSubtitleDiscovery().subtitles(matching: file)
            let plan = ConversionPlan(settings: settings, externalSubtitles: subtitles)
            let output = try await processor.process(
                file,
                outputPolicy: outputPolicy,
                plan: plan,
                probe: probe,
                temporaryDirectoryRoot: temporaryDirectoryRoot,
                progress: { fraction in
                    await reportProgress(.file(file, fraction: fraction))
                }
            )
            outputs.append(output)
            await reportProgress(.batch(processed: index + 1, total: files.count))
        }
        return outputs
    }

    private func validateUniqueDestinations(for files: [URL]) throws {
        var destinations = Set<String>()
        for file in files {
            let destination = file.deletingPathExtension()
                .appendingPathExtension("mp4")
                .standardizedFileURL.path
            guard destinations.insert(destination).inserted else {
                throw VidError.incompatibleOutputOptions(
                    reason: "Multiple inputs would replace '\(destination)'."
                )
            }
        }
    }

    private static let supportedExtensions: Set<String> = [
        "avi", "mkv", "mov", "mp4",
    ]
}
