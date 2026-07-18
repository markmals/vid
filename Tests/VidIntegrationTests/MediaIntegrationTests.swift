import Foundation
import Testing

@testable import vid

@Suite("Real FFmpeg integration", .serialized)
struct MediaIntegrationTests {
    @Test("ffprobe output decodes into classified media streams")
    func probeRealMedia() async throws {
        try await withRealMediaFixture { fixture in
            let probe = try await MediaProber().probe(fixture.input)

            #expect(probe.firstVideoStream?.codecName == "mpeg4")
            #expect(probe.audioStreams.map(\.codecName) == ["aac"])
            #expect(probe.audioStreams.map(\.language) == ["eng"])
            #expect(probe.textSubtitleStreams.map(\.codecName) == ["subrip"])
            #expect(probe.textSubtitleStreams.map(\.language) == ["spa"])
            #expect(probe.bitmapSubtitleStreams.isEmpty)
        }
    }

    @Test("Media processor remuxes real streams into MP4")
    func remuxRealMedia() async throws {
        try await withRealMediaFixture { fixture in
            let processor = MediaProcessor()
            let output = try await processor.process(
                fixture.input,
                outputPolicy: integrationOutputPolicy(),
                plan: RemuxPlan(
                    outputFilenameSuffix: "remuxed",
                    settings: RemuxSettings(
                        isAppleCompatible: false,
                        audioEncoding: .copy,
                        subtitleHandling: .textOnly,
                    ),
                ),
            )
            let probe = try await processor.prober.probe(output)

            #expect(output.lastPathComponent == "sample.mp4")
            #expect(probe.firstVideoStream?.codecName == "mpeg4")
            #expect(probe.audioStreams.map(\.codecName) == ["aac"])
            #expect(probe.textSubtitleStreams.map(\.codecName) == ["mov_text"])
            #expect(probe.textSubtitleStreams.map(\.language) == ["spa"])
        }
    }

    @Test("Media processor performs a real HEVC encode")
    func encodeRealMedia() async throws {
        try await withRealMediaFixture { fixture in
            let processor = MediaProcessor()
            let output = try await processor.process(
                fixture.input,
                outputPolicy: integrationOutputPolicy(),
                plan: EncodePlan(
                    settings: EncodeSettings(
                        audioEncoding: .aac(bitrate: "64k"),
                        crf: 32,
                        excludedAudioLanguages: [],
                        shouldNormalizeDispositions: true,
                        preset: "ultrafast",
                        subtitleHandling: .none,
                    )),
            )
            let probe = try await processor.prober.probe(output)

            #expect(probe.firstVideoStream?.codecName == "hevc")
            #expect(probe.audioStreams.map(\.codecName) == ["aac"])
            #expect(probe.subtitleStreams.isEmpty)
        }
    }

    @Test("Media processor performs a real H.264 repair")
    func repairRealMedia() async throws {
        try await withRealMediaFixture { fixture in
            let processor = MediaProcessor()
            let output = try await processor.process(
                fixture.input,
                outputPolicy: integrationOutputPolicy(),
                plan: RepairPlan(),
            )
            let probe = try await processor.prober.probe(output)

            #expect(probe.firstVideoStream?.codecName == "h264")
            #expect(probe.audioStreams.map(\.codecName) == ["aac"])
            #expect(probe.subtitleStreams.isEmpty)
        }
    }

    @Test("Media processor embeds a real external subtitle")
    func addRealSubtitle() async throws {
        try await withRealMediaFixture { fixture in
            let processor = MediaProcessor()
            let output = try await processor.process(
                fixture.input,
                outputPolicy: integrationOutputPolicy(),
                plan: AddSubtitlePlan(
                    subtitle: fixture.externalSubtitle,
                    language: "fra",
                    title: "French",
                ),
            )
            let probe = try await processor.prober.probe(output)

            #expect(probe.textSubtitleStreams.map(\.codecName) == ["mov_text", "mov_text"])
            #expect(probe.textSubtitleStreams.map(\.language) == ["spa", "fra"])
        }
    }

    @Test("Real FFmpeg failure preserves the source and removes partial output")
    func realFailureCleanup() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("vid-integration-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("broken.mkv")
        try Data("not media".utf8).write(to: input)
        let processor = MediaProcessor()

        await #expect(throws: VidError.self) {
            _ = try await processor.process(
                input,
                outputPolicy: integrationOutputPolicy(),
                plan: RepairPlan(),
                probe: suppliedVideoProbe(),
            )
        }

        #expect(FileManager.default.fileExists(atPath: input.path))
        #expect(
            !FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("broken.mp4").path
            ))
        let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(!remainingFiles.contains { $0.contains(".partial") })
    }
}
