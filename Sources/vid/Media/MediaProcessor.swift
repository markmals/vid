import Foundation

/// A concrete FFmpeg invocation and its staged subtitle sidecar work.
struct FFmpegExecutionPlan: Sendable {
    /// The arguments to pass to the main `ffmpeg` invocation.
    let ffmpegArguments: [String]
    /// Subtitle streams extracted or converted before the main output commits.
    let subtitleExtractions: [SubtitleExtractionPlan]
}

/// Runs a ``MediaOperationPlan`` against an input file, probing it, invoking
/// FFmpeg, extracting sidecar subtitles, and committing the output.
struct MediaProcessor: Sendable {
    /// The prober used to gather stream metadata for inputs.
    let prober: MediaProber
    /// The tool runner used to invoke FFmpeg.
    let runner: ToolRunner

    /// Creates a processor backed by the given tool runner.
    init(runner: ToolRunner = ToolRunner()) {
        self.runner = runner
        prober = MediaProber(runner: runner)
    }

    /// Processes one input, staging every output before replacing the source.
    func process(
        _ input: URL,
        outputPolicy: OutputPolicy,
        plan: some MediaOperationPlan,
        probe suppliedProbe: MediaProbe? = nil,
        temporaryDirectoryRoot: URL = FileManager.default.temporaryDirectory,
        progress: @escaping @Sendable (Double) async -> Void = { _ in },
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
            try await runner.runFFmpeg(
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
        var arguments = FFmpegPlanSupport.inputArguments(extraction.inputURL)
        arguments += [
            "-map", "0:\(extraction.stream.index)?",
            "-c:s", extraction.encoding.ffmpegCodecName,
            sidecar.temporaryURL.path,
        ]
        try await runner.streamOutput(of: "ffmpeg", arguments: arguments)
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
            throw VidError.outputExists(path: finalURL.path)
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
            throw VidError.emptyOutput(path: temporaryURL.path)
        }
    }
}
