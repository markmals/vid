import Foundation
import Testing

@testable import vid

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
        } catch let error as VidError {
            #expect(error.errorDescription?.contains("diagnostic message") == true)
        }

        do {
            _ = try await runner.captureOutput(of: "capture-failure-empty", arguments: [])
            Issue.record("A failed process without stderr should throw")
        } catch let error as VidError {
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
        } catch let error as VidError {
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
struct VidErrorTests {
    @Test("Every error has a specific description")
    func descriptions() {
        let cases: [(VidError, String)] = [
            (.emptyOutput(path: "/empty"), "FFmpeg did not create a non-empty output at '/empty'."),
            (.fileDoesNotExist(path: "/missing"), "No file or directory exists at '/missing'."),
            (
                .invalidOutputDirectory(path: "/file"),
                "The output directory '/file' does not exist or is not a directory."
            ),
            (
                .incompatibleOutputOptions(reason: "conflict"),
                "Incompatible output options: conflict"
            ),
            (.noInputFiles, "No media files matched the supplied paths."),
            (.noVideoStream(path: "/audio"), "'/audio' does not contain a video stream."),
            (
                .outputExists(path: "/output"),
                "Output already exists at '/output'. Pass --overwrite to replace it."
            ),
            (
                .processFailed(tool: "ffmpeg", status: "failed", diagnostic: "details"),
                "ffmpeg failed: details"
            ),
            (.processFailed(tool: "ffmpeg", status: "failed", diagnostic: ""), "ffmpeg failed."),
            (.processFailed(tool: "ffmpeg", status: "failed", diagnostic: nil), "ffmpeg failed."),
            (
                .unreadableProbe(path: "/probe"),
                "ffprobe returned invalid media information for '/probe'."
            ),
        ]

        for (error, description) in cases {
            #expect(error.errorDescription == description)
        }
    }
}
