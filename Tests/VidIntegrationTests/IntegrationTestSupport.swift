import Foundation

@testable import CommandExecution
@testable import FFprobe
@testable import MediaProcessing

struct RealMediaFixture {
    let directory: URL
    let externalSubtitle: URL
    let input: URL

    static func make() async throws -> Self {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vid-integration-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            let embeddedSubtitle = directory.appendingPathComponent("embedded.srt")
            let externalSubtitle = directory.appendingPathComponent("external.srt")
            try subtitle(text: "Hola").write(
                to: embeddedSubtitle,
                atomically: true,
                encoding: .utf8,
            )
            try subtitle(text: "Bonjour").write(
                to: externalSubtitle,
                atomically: true,
                encoding: .utf8,
            )

            let input = directory.appendingPathComponent("sample.mkv")
            _ = try await ToolRunner().captureOutput(
                of: "ffmpeg",
                arguments: [
                    "-v", "error",
                    "-nostdin",
                    "-y",
                    "-f", "lavfi",
                    "-i", "testsrc2=size=64x64:rate=10:duration=0.5",
                    "-f", "lavfi",
                    "-i", "sine=frequency=1000:sample_rate=48000:duration=0.5",
                    "-i", embeddedSubtitle.path,
                    "-map", "0:v:0",
                    "-map", "1:a:0",
                    "-map", "2:s:0",
                    "-c:v", "mpeg4",
                    "-q:v", "5",
                    "-c:a", "aac",
                    "-b:a", "64k",
                    "-c:s", "srt",
                    "-metadata:s:a:0", "language=ENG",
                    "-metadata:s:s:0", "language=spa",
                    "-threads", "1",
                    "-shortest",
                    input.path,
                ],
            )

            return Self(
                directory: directory,
                externalSubtitle: externalSubtitle,
                input: input,
            )
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func subtitle(text: String) -> String {
        """
        1
        00:00:00,000 --> 00:00:00,400
        \(text)

        """
    }
}

func withRealMediaFixture<T>(
    _ operation: (RealMediaFixture) async throws -> T
) async throws -> T {
    let fixture = try await RealMediaFixture.make()
    defer { fixture.remove() }
    return try await operation(fixture)
}

func integrationOutputPolicy(
    overwrite: Bool = false,
    removeSource: Bool = false
) -> OutputPolicy {
    OutputPolicy(
        outputDirectory: nil,
        shouldOverwriteExistingOutput: overwrite,
        shouldRemoveSource: removeSource,
        shouldReplaceInput: false,
    )
}

func suppliedVideoProbe() -> MediaProbe {
    MediaProbe(streams: [
        MediaStream(
            index: 0,
            codecName: "h264",
            codecType: "video",
            disposition: nil,
            tags: nil,
        )
    ])
}
