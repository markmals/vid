import Foundation
import Testing

@testable import CommandExecution
@testable import FFprobe
@testable import MediaDiscovery
@testable import MediaProcessing

@Suite("Tool execution")
struct ToolRunnerTests {
    @Test("Captured and streamed tools report success and failure")
    func runnerOutcomes() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let capture = try makeExecutable(
            in: directory,
            name: "capture",
            script: "printf 'captured output'",
        )
        let emptyCapture = try makeExecutable(
            in: directory,
            name: "empty-capture",
            script: ":",
        )
        let captureFailure = try makeExecutable(
            in: directory,
            name: "capture-failure",
            script: "printf ' diagnostic message \\n' >&2; exit 7",
        )
        let captureFailureWithoutDiagnostic = try makeExecutable(
            in: directory,
            name: "capture-failure-empty",
            script: "exit 2",
        )
        let stream = try makeExecutable(
            in: directory,
            name: "stream",
            script: ":",
        )
        let streamFailure = try makeExecutable(
            in: directory,
            name: "stream-failure",
            script: "exit 3",
        )
        let runner = ToolRunner(executablePaths: [
            "capture": capture.path,
            "empty-capture": emptyCapture.path,
            "capture-failure": captureFailure.path,
            "capture-failure-empty": captureFailureWithoutDiagnostic.path,
            "stream": stream.path,
            "stream-failure": streamFailure.path,
        ])

        #expect(try await runner.captureOutput(of: "capture", arguments: []) == "captured output")
        #expect(try await runner.captureOutput(of: "empty-capture", arguments: []).isEmpty)

        do {
            _ = try await runner.captureOutput(of: "capture-failure", arguments: [])
            Issue.record("A failed captured process should throw")
        } catch let error as CommandExecutionError {
            #expect(error.errorDescription?.contains("diagnostic message") == true)
        }

        do {
            _ = try await runner.captureOutput(of: "capture-failure-empty", arguments: [])
            Issue.record("A failed process without stderr should throw")
        } catch let error as CommandExecutionError {
            #expect(error.errorDescription?.hasSuffix(".") == true)
        }

        try await runner.streamOutput(
            of: "stream",
            arguments: [
                "plain", "two words", "single'quote", "double\"quote", "back\\slash", "$value",
            ],
        )
        do {
            try await runner.streamOutput(of: "stream-failure", arguments: [])
            Issue.record("A failed streamed process should throw")
        } catch let error as CommandExecutionError {
            #expect(error.errorDescription?.contains("stream-failure") == true)
        }
    }

    @Test("Default runner resolves tools through PATH")
    func pathResolution() async throws {
        let output = try await ToolRunner().captureOutput(
            of: "printf",
            arguments: ["path output"],
        )
        #expect(output == "path output")
    }
}

@Suite("User-facing errors")
struct ModuleErrorTests {
    @Test("Every module error has a specific description")
    func descriptions() {
        let descriptions: [String?] = [
            MediaProcessingError.emptyOutput(path: "/empty").errorDescription,
            MediaDiscoveryError.fileDoesNotExist(path: "/missing").errorDescription,
            MediaProcessingError.invalidOutputDirectory(path: "/file").errorDescription,
            MediaProcessingError.incompatibleOutputOptions(reason: "conflict").errorDescription,
            MediaDiscoveryError.noInputFiles.errorDescription,
            MediaProcessingError.noVideoStream(path: "/audio").errorDescription,
            MediaProcessingError.outputExists(path: "/output").errorDescription,
            CommandExecutionError(
                tool: "ffmpeg",
                status: "failed",
                diagnostic: "details"
            ).errorDescription,
            CommandExecutionError(
                tool: "ffmpeg",
                status: "failed",
                diagnostic: ""
            ).errorDescription,
            CommandExecutionError(
                tool: "ffmpeg",
                status: "failed",
                diagnostic: nil
            ).errorDescription,
            MediaProbeError.unreadableProbe(path: "/probe").errorDescription,
        ]
        let expected: [String?] = [
            "FFmpeg did not create a non-empty output at '/empty'.",
            "No file or directory exists at '/missing'.",
            "The output directory '/file' does not exist or is not a directory.",
            "Incompatible output options: conflict",
            "No media files matched the supplied paths.",
            "'/audio' does not contain a video stream.",
            "Output already exists at '/output'. Pass --overwrite to replace it.",
            "ffmpeg failed: details",
            "ffmpeg failed.",
            "ffmpeg failed.",
            "ffprobe returned invalid media information for '/probe'.",
        ]

        #expect(descriptions == expected)
    }
}
