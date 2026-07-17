import Foundation
import Testing

@testable import vid

@Suite("FFmpeg plans")
struct MediaPlanTests {
    @Test("Apple remux tags HEVC and Dolby streams while extracting bitmap subtitles")
    func appleRemuxPlan() throws {
        let probe = MediaProbe(streams: [
            stream(index: 0, codec: "hevc", type: "video"),
            stream(index: 1, codec: "eac3", type: "audio", language: "eng"),
            stream(index: 2, codec: "subrip", type: "subtitle", language: "eng"),
            stream(index: 3, codec: "hdmv_pgs_subtitle", type: "subtitle", language: "eng"),
        ])
        let plan = RemuxPlan(
            outputFilenameSuffix: "tagged",
            settings: RemuxSettings(
                isAppleCompatible: true,
                audioEncoding: .copy,
                subtitleHandling: .extractBitmap,
            ),
        )

        let executionPlan = try plan.makeExecutionPlan(
            input: URL(fileURLWithPath: "/media/input.mkv"),
            output: URL(fileURLWithPath: "/media/output.mp4"),
            probe: probe,
        )

        #expect(
            executionPlan.ffmpegArguments.containsSequence(["-bsf:v", "hevc_metadata=aud=insert"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-tag:v:0", "hvc1"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-tag:a:0", "ec-3"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-map", "0:2?"]))
        #expect(!executionPlan.ffmpegArguments.containsSequence(["-map", "0:3?"]))
        #expect(executionPlan.bitmapSubtitlesToExtract.map(\.index) == [3])
    }

    @Test("HEVC encoding excludes selected audio languages and normalizes defaults")
    func encodePlan() throws {
        let probe = MediaProbe(streams: [
            stream(index: 0, codec: "h264", type: "video"),
            stream(index: 1, codec: "aac", type: "audio", language: "eng"),
            stream(index: 2, codec: "aac", type: "audio", language: "rus"),
            stream(index: 3, codec: "subrip", type: "subtitle", language: "eng"),
        ])
        let plan = EncodePlan(
            settings: EncodeSettings(
                audioEncoding: .eac3(bitrate: "320k"),
                crf: 23,
                excludedAudioLanguages: ["rus"],
                shouldNormalizeDispositions: true,
                preset: "medium",
                subtitleHandling: .textOnly,
            ),
        )

        let executionPlan = try plan.makeExecutionPlan(
            input: URL(fileURLWithPath: "/media/input.mkv"),
            output: URL(fileURLWithPath: "/media/output.mp4"),
            probe: probe,
        )

        #expect(executionPlan.ffmpegArguments.containsSequence(["-map", "0:1?"]))
        #expect(!executionPlan.ffmpegArguments.containsSequence(["-map", "0:2?"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-c:v", "libx265"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-c:a", "eac3", "-b:a", "320k"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-disposition:a:0", "default"]))
        #expect(executionPlan.ffmpegArguments.containsSequence(["-disposition:s:0", "default"]))
    }

    private func stream(
        index: Int,
        codec: String,
        type: String,
        language: String? = nil,
    ) -> MediaStream {
        MediaStream(
            index: index,
            codecName: codec,
            codecType: type,
            disposition: nil,
            tags: language.map(MediaStream.Tags.init(language:)),
        )
    }
}

extension [String] {
    fileprivate func containsSequence(_ expected: [String]) -> Bool {
        guard !expected.isEmpty, count >= expected.count else {
            return false
        }

        for start in 0...(count - expected.count) {
            if Array(self[start..<(start + expected.count)]) == expected {
                return true
            }
        }
        return false
    }
}
