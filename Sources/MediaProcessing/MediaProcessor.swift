import FFmpeg
import FFprobe
import Foundation

/// A concrete FFmpeg invocation and its staged subtitle sidecar work.
public struct FFmpegExecutionPlan: Sendable {
    /// The arguments to pass to the main `ffmpeg` invocation.
    public let ffmpegArguments: [String]
    /// Subtitle streams extracted or converted before the main output commits.
    public let subtitleExtractions: [SubtitleExtractionPlan]

    /// Creates a concrete media execution plan.
    public init(
        ffmpegArguments: [String],
        subtitleExtractions: [SubtitleExtractionPlan]
    ) {
        self.ffmpegArguments = ffmpegArguments
        self.subtitleExtractions = subtitleExtractions
    }
}

/// Runs a ``MediaOperationPlan`` against an input file, probing it, invoking
/// FFmpeg, extracting sidecar subtitles, and committing the output.
public struct MediaProcessor: Sendable {
    private let prober: any MediaProbing
    private let runner: any FFmpegRunning

    /// Creates a processor with independently replaceable probe and FFmpeg services.
    public init(
        prober: any MediaProbing = MediaProber(),
        runner: any FFmpegRunning = FFmpegRunner()
    ) {
        self.prober = prober
        self.runner = runner
    }

    /// Processes one input through a staged FFmpeg transaction.
    ///
    /// The method prints processing and creation messages to standard output.
    /// It commits the main output and extracted subtitle sidecars only after all
    /// FFmpeg work succeeds, and rolls staged work back after a failure.
    ///
    /// - Parameters:
    ///   - input: The source media file.
    ///   - outputPolicy: The destination and source-replacement behavior.
    ///   - plan: The operation that builds FFmpeg and subtitle extraction work.
    ///   - suppliedProbe: Probe metadata to use instead of invoking the prober.
    ///   - temporaryDirectoryRoot: The root under which the method creates its
    ///     isolated temporary workspace.
    ///   - progress: An asynchronous observer for completion fractions emitted
    ///     by the configured FFmpeg runner.
    /// - Returns: The final URL of the committed main output.
    /// - Throws: An error from probing, planning, staging, FFmpeg execution,
    ///   output validation, or transaction commit.
    public func process(
        _ input: URL,
        outputPolicy: OutputPolicy,
        plan: some MediaOperationPlan,
        probe suppliedProbe: MediaProbe? = nil,
        temporaryDirectoryRoot: URL = FileManager.default.temporaryDirectory,
        progress: @escaping @Sendable (_ fraction: Double) async -> Void = { _ in },
    ) async throws -> URL {
        print("Processing \(input.path)")
        let probe: MediaProbe
        if let suppliedProbe {
            probe = suppliedProbe
        } else {
            probe = try await prober.probe(input)
        }
        let output = try OutputTransaction(
            sourceURL: input,
            outputFilenameSuffix: plan.outputFilenameSuffix,
            policy: outputPolicy,
            temporaryDirectoryRoot: temporaryDirectoryRoot
        )
        var sidecars: [SidecarTransaction] = []
        do {
            let executionPlan = try plan.makeExecutionPlan(
                input: input,
                output: output.temporaryURL,
                probe: probe
            )
            sidecars = try executionPlan.subtitleExtractions.map { extraction in
                try SidecarTransaction(
                    extraction: extraction,
                    outputDirectory: output.finalURL.deletingLastPathComponent(),
                    temporaryDirectory: output.temporaryDirectoryURL,
                    overwrite: outputPolicy.shouldOverwriteExistingOutput
                )
            }

            for sidecar in sidecars {
                try await extract(sidecar)
            }
            try await runner.run(
                arguments: executionPlan.ffmpegArguments,
                durationSeconds: probe.durationSeconds,
                onProgress: progress
            )
            for sidecar in sidecars {
                try sidecar.commit()
            }
            try output.commit()
        } catch {
            for sidecar in sidecars.reversed() {
                sidecar.rollback()
            }
            output.discardTemporaryOutput()
            throw error
        }

        print("Created \(output.finalURL.path)")
        for sidecar in sidecars {
            print("Extracted \(sidecar.finalURL.path)")
        }
        return output.finalURL
    }

    private func extract(_ sidecar: SidecarTransaction) async throws {
        let extraction = sidecar.extraction
        var arguments = FFmpegPlanSupport.inputArguments(for: extraction.inputURL)
        arguments += [
            "-map", "0:\(extraction.stream.index)?",
            "-c:s", extraction.encoding.ffmpegCodecName,
            sidecar.temporaryURL.path,
        ]
        try await runner.run(arguments: arguments)
        try sidecar.ensureNonEmptyOutput()
    }
}

private final class SidecarTransaction: @unchecked Sendable {
    let extraction: SubtitleExtractionPlan
    let finalURL: URL
    let temporaryURL: URL

    private let backupURL: URL
    private var didCommit = false

    init(
        extraction: SubtitleExtractionPlan,
        outputDirectory: URL,
        temporaryDirectory: URL,
        overwrite: Bool
    ) throws {
        self.extraction = extraction
        finalURL = outputDirectory.appendingPathComponent(extraction.outputFilename)
        if FileManager.default.fileExists(atPath: finalURL.path), !overwrite {
            throw MediaProcessingError.outputExists(path: finalURL.path)
        }

        let outputExtension = finalURL.pathExtension
        temporaryURL = temporaryDirectory.appendingPathComponent(
            "sidecar-\(UUID().uuidString).\(outputExtension)"
        )
        backupURL = temporaryDirectory.appendingPathComponent(
            "replaced-sidecar-\(UUID().uuidString).\(outputExtension)"
        )
    }

    func commit() throws {
        try ensureNonEmptyOutput()
        let fileManager = FileManager.default
        let replacesExistingOutput = fileManager.fileExists(atPath: finalURL.path)
        if replacesExistingOutput {
            try fileManager.moveItem(at: finalURL, to: backupURL)
        }

        do {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
            didCommit = true
        } catch {
            if replacesExistingOutput, fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.moveItem(at: backupURL, to: finalURL)
            }
            throw error
        }
    }

    func rollback() {
        let fileManager = FileManager.default
        if didCommit, fileManager.fileExists(atPath: finalURL.path) {
            try? fileManager.removeItem(at: finalURL)
        }
        if fileManager.fileExists(atPath: backupURL.path) {
            try? fileManager.moveItem(at: backupURL, to: finalURL)
        }
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try? fileManager.removeItem(at: temporaryURL)
        }
        didCommit = false
    }

    func ensureNonEmptyOutput() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > 0 else {
            throw MediaProcessingError.emptyOutput(path: temporaryURL.path)
        }
    }
}
