import Foundation
import Testing

@testable import CommandExecution
@testable import FFmpeg
@testable import FFprobe
@testable import MediaProcessing
@testable import MediaRemux
@testable import MediaRepair

@Suite("Media processor")
struct MediaProcessorTests {
    @Test("Processing commits media and extracted bitmap subtitles")
    func successfulProcessing() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(
            directory.appendingPathComponent("movie.mkv"), contents: "source")
        let ffmpeg = try makeExecutable(
            in: directory,
            name: "ffmpeg-success",
            script: """
                output=''
                for argument do output="$argument"; done
                printf 'generated' > "$output"
                """,
        )
        let processor = mediaProcessor(
            runner: ToolRunner(executablePaths: ["ffmpeg": ffmpeg.path])
        )
        let plan = RemuxPlan(
            outputFilenameSuffix: "remuxed",
            settings: RemuxSettings(
                isAppleCompatible: false,
                audioEncoding: .copy,
                subtitleHandling: .extractBitmap,
            ),
        )

        let output = try await processor.process(
            input,
            outputPolicy: outputPolicy(),
            plan: plan,
            probe: mediaProbe(includeBitmapSubtitle: true),
        )

        #expect(output.lastPathComponent == "movie.mp4")
        #expect(FileManager.default.fileExists(atPath: output.path))
        #expect(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("movie_sub3.sup").path
            ))
    }

    @Test("Processing probes when no probe is supplied")
    func probesInput() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("probed.mkv"))
        let ffprobe = try makeExecutable(
            in: directory,
            name: "ffprobe-success",
            script:
                "printf '%s\\n' '{\"streams\":[{\"index\":0,\"codec_name\":\"h264\",\"codec_type\":\"video\"}]}'",
        )
        let ffmpeg = try makeExecutable(
            in: directory,
            name: "ffmpeg-success",
            script:
                "output=''; for argument do output=\"$argument\"; done; printf 'generated' > \"$output\"",
        )
        let runner = ToolRunner(executablePaths: [
            "ffprobe": ffprobe.path,
            "ffmpeg": ffmpeg.path,
        ])

        let output = try await mediaProcessor(runner: runner).process(
            input,
            outputPolicy: outputPolicy(),
            plan: RepairPlan(),
        )
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    @Test("A failed main output discards all temporary files")
    func failureCleanup() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("failure.mkv"))
        let ffmpeg = try makeExecutable(
            in: directory,
            name: "ffmpeg-main-failure",
            script: """
                output=''
                for argument do output="$argument"; done
                printf 'partial' > "$output"
                case "$output" in
                    *.mp4) exit 9 ;;
                esac
                """,
        )
        let processor = mediaProcessor(
            runner: ToolRunner(executablePaths: ["ffmpeg": ffmpeg.path])
        )
        let plan = RemuxPlan(
            outputFilenameSuffix: "remuxed",
            settings: RemuxSettings(
                isAppleCompatible: false,
                audioEncoding: .copy,
                subtitleHandling: .extractBitmap,
            ),
        )

        await #expect(throws: CommandExecutionError.self) {
            _ = try await processor.process(
                input,
                outputPolicy: outputPolicy(),
                plan: plan,
                probe: mediaProbe(includeBitmapSubtitle: true),
            )
        }
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(remaining == ["failure.mkv", "ffmpeg-main-failure"])
    }

    @Test("Empty and colliding sidecars fail without replacing existing output")
    func sidecarFailures() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("sidecar.mkv"))
        let emptyFFmpeg = try makeExecutable(
            in: directory,
            name: "ffmpeg-empty",
            script: "output=''; for argument do output=\"$argument\"; done; : > \"$output\"",
        )
        let processor = mediaProcessor(
            runner: ToolRunner(executablePaths: ["ffmpeg": emptyFFmpeg.path])
        )
        let plan = RemuxPlan(
            outputFilenameSuffix: "remuxed",
            settings: RemuxSettings(
                isAppleCompatible: false,
                audioEncoding: .copy,
                subtitleHandling: .extractBitmap,
            ),
        )

        await #expect(throws: MediaProcessingError.self) {
            _ = try await processor.process(
                input,
                outputPolicy: outputPolicy(),
                plan: plan,
                probe: mediaProbe(includeBitmapSubtitle: true),
            )
        }
        let failedExtraction = try makeExecutable(
            in: directory,
            name: "ffmpeg-extraction-failure",
            script: "exit 8",
        )
        let failedExtractionProcessor = mediaProcessor(
            runner: ToolRunner(executablePaths: ["ffmpeg": failedExtraction.path])
        )
        await #expect(throws: CommandExecutionError.self) {
            _ = try await failedExtractionProcessor.process(
                input,
                outputPolicy: outputPolicy(),
                plan: plan,
                probe: mediaProbe(includeBitmapSubtitle: true),
            )
        }

        let existingSidecar = try writeTestFile(
            directory.appendingPathComponent("sidecar_sub3.sup"),
            contents: "existing",
        )
        await #expect(throws: MediaProcessingError.self) {
            _ = try await processor.process(
                input,
                outputPolicy: outputPolicy(),
                plan: plan,
                probe: mediaProbe(includeBitmapSubtitle: true),
            )
        }
        #expect(try String(contentsOf: existingSidecar, encoding: .utf8) == "existing")
    }

    @Test("Overwriting replaces an existing sidecar")
    func sidecarOverwrite() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("overwrite.mkv"))
        let sidecar = try writeTestFile(
            directory.appendingPathComponent("overwrite_sub3.sup"),
            contents: "old",
        )
        let ffmpeg = try makeExecutable(
            in: directory,
            name: "ffmpeg-overwrite",
            script:
                "output=''; for argument do output=\"$argument\"; done; printf 'new' > \"$output\"",
        )
        let plan = RemuxPlan(
            outputFilenameSuffix: "remuxed",
            settings: RemuxSettings(
                isAppleCompatible: false,
                audioEncoding: .copy,
                subtitleHandling: .extractBitmap,
            ),
        )

        _ = try await mediaProcessor(
            runner: ToolRunner(executablePaths: ["ffmpeg": ffmpeg.path])
        ).process(
            input,
            outputPolicy: outputPolicy(overwrite: true),
            plan: plan,
            probe: mediaProbe(includeBitmapSubtitle: true),
        )
        #expect(try String(contentsOf: sidecar, encoding: .utf8) == "new")
    }
}
