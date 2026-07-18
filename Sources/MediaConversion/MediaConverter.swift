import Foundation
import MediaDiscovery
import MediaProcessing

/// Progress emitted while converting one file or a recursive batch.
public enum MediaConversionProgress: Equatable, Sendable {
    /// Progress through the current FFmpeg conversion, from zero through one.
    case file(URL, fraction: Double)
    /// Number of files successfully processed out of the discovered total.
    case batch(processed: Int, total: Int)
}

/// Discovers and safely replaces existing media with Apple-compatible MP4 files.
public struct MediaConverter: Sendable {
    private let processor: MediaProcessor
    private let reportProgress: @Sendable (_ progress: MediaConversionProgress) async -> Void
    private let temporaryDirectoryRoot: URL

    /// Creates a converter with independently injectable processing, temporary
    /// storage, and progress reporting.
    public init(
        processor: MediaProcessor = MediaProcessor(),
        temporaryDirectoryRoot: URL = FileManager.default.temporaryDirectory,
        reportProgress: @escaping @Sendable (_ progress: MediaConversionProgress) async -> Void = {
            _ in
        }
    ) {
        self.processor = processor
        self.temporaryDirectoryRoot = temporaryDirectoryRoot
        self.reportProgress = reportProgress
    }

    /// Recursively converts one file or every supported file beneath a directory.
    ///
    /// For each input, the conversion discovers matching subtitle files, embeds
    /// the preferred text track, stages the remaining subtitles as sidecars,
    /// commits an Apple-compatible MP4, and then removes or replaces the source.
    /// The converter reports batch and per-file progress through the callback
    /// supplied at initialization.
    ///
    /// - Parameters:
    ///   - path: The file or directory to discover and convert.
    ///   - videoCodec: The video codec to use when re-encoding is required.
    /// - Returns: The final MP4 URLs, in discovery order.
    /// - Throws: An error when discovery, destination validation, probing,
    ///   FFmpeg execution, subtitle processing, or an output transaction fails.
    public func convert(
        _ path: String,
        videoCodec: ConversionVideoCodec
    ) async throws -> [URL] {
        let files = try InputDiscovery().mediaFiles(
            at: [path],
            recursive: true,
            supportedExtensions: Self.supportedExtensions
        )
        try validateUniqueDestinations(for: files)
        await reportProgress(.batch(processed: 0, total: files.count))

        let settings = MediaConversionSettings.makeHighQuality(videoCodec: videoCodec)
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
            let subtitles = try ExternalSubtitleDiscovery().subtitles(matching: file)
            let plan = ConversionPlan(settings: settings, externalSubtitles: subtitles)
            let output = try await processor.process(
                file,
                outputPolicy: outputPolicy,
                plan: plan,
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
                throw MediaProcessingError.incompatibleOutputOptions(
                    reason: "Multiple inputs would replace '\(destination)'."
                )
            }
        }
    }

    private static let supportedExtensions: Set<String> = [
        "avi", "mkv", "mov", "mp4",
    ]
}
