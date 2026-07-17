import Foundation

struct MediaProcessingPlan: Sendable {
    let ffmpegArguments: [String]
    let bitmapSubtitlesToExtract: [MediaStream]
}

struct MediaProcessor: Sendable {
    let prober: MediaProber
    let runner: ToolRunner

    init(runner: ToolRunner = ToolRunner()) {
        self.runner = runner
        prober = MediaProber(runner: runner)
    }

    func process(
        _ input: URL,
        outputPolicy: OutputPolicy,
        plan: some MediaPlan,
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
            operationName: plan.operationName,
            policy: outputPolicy,
        )
        let processingPlan = try plan.makeProcessingPlan(
            input: input,
            output: output.temporaryURL,
            probe: probe,
        )
        let sidecars = try makeSidecars(
            for: processingPlan.bitmapSubtitlesToExtract,
            input: input,
            outputDirectory: output.finalURL.deletingLastPathComponent(),
            overwrite: outputPolicy.overwrite,
        )

        do {
            for sidecar in sidecars {
                try await extract(sidecar, from: input)
            }
            try await runner.stream("ffmpeg", arguments: processingPlan.ffmpegArguments)
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
        try await runner.stream(
            "ffmpeg",
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
            throw VidError.outputExists(finalURL.path)
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
            throw VidError.emptyOutput(temporaryURL.path)
        }
    }
}
