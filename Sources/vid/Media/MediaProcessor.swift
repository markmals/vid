import Foundation

/// A compiled, concrete plan for running FFmpeg against a single input file.
///
/// It carries the exact FFmpeg arguments to invoke along with any bitmap
/// subtitle streams that must be extracted to sidecar files.
struct FFmpegExecutionPlan: Sendable {
    /// The arguments to pass to the `ffmpeg` invocation.
    let ffmpegArguments: [String]
    /// The bitmap subtitle streams to extract into sidecar files.
    let bitmapSubtitlesToExtract: [MediaStream]
}

/// Runs a ``MediaOperationPlan`` against an input file, probing it, invoking
/// FFmpeg, extracting sidecar subtitles, and committing the output.
struct MediaProcessor: Sendable {
    /// The prober used to gather stream metadata for inputs.
    let prober: MediaProber
    /// The tool runner used to invoke `ffmpeg`.
    let runner: ToolRunner

    /// Creates a processor backed by the given tool runner.
    ///
    /// - Parameter runner: The tool runner used to invoke subprocesses; it also
    ///   backs the internal ``MediaProber``.
    init(runner: ToolRunner = ToolRunner()) {
        self.runner = runner
        prober = MediaProber(runner: runner)
    }

    /// Processes a single input file according to the supplied plan.
    ///
    /// The input is probed (unless a probe is supplied), an ``OutputTransaction``
    /// resolves the destination, the plan is compiled to FFmpeg arguments, any
    /// bitmap subtitle sidecars are extracted, FFmpeg is run, and all outputs
    /// are committed. If any step fails, the temporary outputs are discarded and
    /// the error is rethrown.
    ///
    /// - Parameters:
    ///   - input: The source media file to process.
    ///   - outputPolicy: The resolved output behavior for the operation.
    ///   - plan: The operation plan describing the work to perform.
    ///   - suppliedProbe: A pre-computed probe to reuse instead of probing
    ///     `input` again.
    /// - Returns: The URL of the committed output file.
    /// - Throws: A ``VidError`` or filesystem/subprocess error if probing,
    ///   output resolution, extraction, FFmpeg execution, or commit fails.
    func process(
        _ input: URL,
        outputPolicy: OutputPolicy,
        plan: some MediaOperationPlan,
        probe suppliedProbe: MediaProbe? = nil,
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
        )
        let executionPlan = try plan.makeExecutionPlan(
            input: input,
            output: output.temporaryURL,
            probe: probe,
        )
        let sidecars = try makeSidecars(
            for: executionPlan.bitmapSubtitlesToExtract,
            input: input,
            outputDirectory: output.finalURL.deletingLastPathComponent(),
            overwrite: outputPolicy.shouldOverwriteExistingOutput,
        )

        do {
            for sidecar in sidecars {
                try await extract(sidecar, from: input)
            }
            try await runner.streamOutput(of: "ffmpeg", arguments: executionPlan.ffmpegArguments)
            try output.commit()
            for sidecar in sidecars {
                try sidecar.commit()
            }
        } catch {
            output.discardTemporaryOutput()
            for sidecar in sidecars {
                sidecar.discardTemporaryOutput()
            }
            throw error
        }

        print("Created \(output.finalURL.path)")
        for sidecar in sidecars {
            print("Extracted \(sidecar.finalURL.path)")
        }
        return output.finalURL
    }

    private func extract(_ sidecar: SidecarTransaction, from input: URL) async throws {
        try await runner.streamOutput(
            of: "ffmpeg",
            arguments: [
                "-hide_banner", "-nostdin", "-y",
                "-probesize", "50M",
                "-analyzeduration", "50M",
                "-i", input.path,
                "-map", "0:\(sidecar.streamIndex)?",
                "-c", "copy",
                sidecar.temporaryURL.path,
            ],
        )
        try sidecar.ensureNonEmptyOutput()
    }

    private func makeSidecars(
        for streams: [MediaStream],
        input: URL,
        outputDirectory: URL,
        overwrite: Bool,
    ) throws -> [SidecarTransaction] {
        let baseName = input.deletingPathExtension().lastPathComponent
        return try streams.map { stream in
            try SidecarTransaction(
                baseName: baseName,
                outputDirectory: outputDirectory,
                overwrite: overwrite,
                stream: stream,
            )
        }
    }
}

private struct SidecarTransaction: Sendable {
    let finalURL: URL
    let streamIndex: Int
    let temporaryURL: URL

    init(
        baseName: String,
        outputDirectory: URL,
        overwrite: Bool,
        stream: MediaStream,
    ) throws {
        let fileName = "\(baseName)_sub\(stream.index).\(stream.subtitleFileExtension)"
        finalURL = outputDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: finalURL.path), !overwrite {
            throw VidError.outputExists(path: finalURL.path)
        }

        let temporaryName =
            ".\(baseName)_sub\(stream.index).vid-\(UUID().uuidString).partial.\(stream.subtitleFileExtension)"
        temporaryURL = outputDirectory.appendingPathComponent(temporaryName)
        streamIndex = stream.index
    }

    func commit() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: finalURL)
        }
    }

    func discardTemporaryOutput() {
        guard FileManager.default.fileExists(atPath: temporaryURL.path) else {
            return
        }
        try? FileManager.default.removeItem(at: temporaryURL)
    }

    func ensureNonEmptyOutput() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        guard let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > 0 else {
            throw VidError.emptyOutput(path: temporaryURL.path)
        }
    }
}
