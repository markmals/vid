import Foundation
import Testing

@testable import CommandExecution
@testable import FFprobe

@Suite("Media probing")
struct MediaProbeTests {
    @Test("Probe decoding classifies streams and normalizes metadata")
    func decodingAndClassification() throws {
        let json = """
            {
              "streams": [
                {"index": 0, "codec_name": "mjpeg", "codec_type": "video", "disposition": {"attached_pic": 1}},
                {"index": 1, "codec_name": "hevc", "codec_type": "video", "disposition": {"attached_pic": 0}},
                {"index": 2, "codec_name": "aac", "codec_type": "audio", "tags": {"language": "ENG"}},
                {"index": 3, "codec_name": "subrip", "codec_type": "subtitle"},
                {"index": 4, "codec_name": "hdmv_pgs_subtitle", "codec_type": "subtitle"},
                {"index": 5, "codec_name": "xsub", "codec_type": "subtitle"},
                {"index": 6, "codec_name": "dvd_subtitle", "codec_type": "subtitle"},
                {"index": 7, "codec_name": "dvb_subtitle", "codec_type": "subtitle"},
                {"index": 8, "codec_type": "subtitle"}
              ]
            }
            """
        let probe = try JSONDecoder().decode(MediaProbe.self, from: Data(json.utf8))

        #expect(probe.firstVideoStream?.index == 1)
        #expect(probe.audioStreams.map(\.index) == [2])
        #expect(probe.audioStreams.first?.language == "eng")
        #expect(probe.subtitleStreams.map(\.index) == [3, 4, 5, 6, 7, 8])
        #expect(probe.textSubtitleStreams.map(\.index) == [3, 8])
        #expect(probe.bitmapSubtitleStreams.map(\.index) == [4, 5, 6, 7])
        #expect(probe.streams[4].subtitleFileExtension == "sup")
        #expect(probe.streams[5].subtitleFileExtension == "xsub")
        #expect(probe.streams[6].subtitleFileExtension == "sub")
        #expect(probe.streams[8].language == nil)
        #expect(!probe.streams[8].isBitmapSubtitle)
    }

    @Test("Media prober decodes valid and audio-only output and reports invalid probes")
    func proberOutcomes() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = try writeTestFile(directory.appendingPathComponent("movie.mkv"))

        let valid = try makeExecutable(
            in: directory,
            name: "valid-probe",
            script:
                "printf '%s\\n' '{\"streams\":[{\"index\":0,\"codec_name\":\"h264\",\"codec_type\":\"video\"}]}'",
        )
        let validProbe = try await MediaProber(
            runner: ToolRunner(executablePaths: ["ffprobe": valid.path])
        ).probe(input)
        #expect(validProbe.firstVideoStream?.codecName == "h264")

        let invalid = try makeExecutable(
            in: directory,
            name: "invalid-probe",
            script: "printf 'not json'",
        )
        do {
            _ = try await MediaProber(
                runner: ToolRunner(executablePaths: ["ffprobe": invalid.path])
            ).probe(input)
            Issue.record("Invalid JSON should fail")
        } catch let error as MediaProbeError {
            #expect(
                error.errorDescription
                    == "ffprobe returned invalid media information for '\(input.path)'.")
        }

        let audioOnly = try makeExecutable(
            in: directory,
            name: "audio-probe",
            script:
                "printf '%s\\n' '{\"streams\":[{\"index\":0,\"codec_name\":\"aac\",\"codec_type\":\"audio\"}]}'",
        )
        let audioProbe = try await MediaProber(
            runner: ToolRunner(executablePaths: ["ffprobe": audioOnly.path])
        ).probe(input)
        #expect(audioProbe.firstVideoStream == nil)
        #expect(audioProbe.audioStreams.map(\.codecName) == ["aac"])
    }
}
