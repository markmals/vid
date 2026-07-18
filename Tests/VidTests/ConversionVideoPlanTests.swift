import Foundation
import Testing

@testable import vid

@Suite("Conversion video plans")
struct ConversionVideoPlanTests {
    @Test("H.264 conversion copies AVC and HEVC but encodes other codecs")
    func h264CopyAndEncodeSelection() throws {
        for sourceCodec in ["h264", "hevc"] {
            let execution = try makePlan(
                target: .h264,
                videoCodec: sourceCodec,
                videoTag: sourceCodec == "hevc" ? "hvc1" : "avc1"
            )

            #expect(execution.ffmpegArguments.containsSequence(["-c:v", "copy"]))
            #expect(!execution.ffmpegArguments.contains("libx264"))
            #expect(!execution.ffmpegArguments.contains("libx265"))
        }

        let vp9Execution = try makePlan(target: .h264, videoCodec: "vp9")
        #expect(vp9Execution.ffmpegArguments.containsSequence(["-c:v", "libx264"]))
        #expect(vp9Execution.ffmpegArguments.containsSequence(["-preset", "veryslow"]))
        #expect(vp9Execution.ffmpegArguments.containsSequence(["-crf", "18"]))
    }

    @Test("H.265 conversion copies HEVC, repairs its tag, and encodes other codecs")
    func h265CopyTagAndEncodeSelection() throws {
        for tag in ["hvc1", "hev1"] {
            let execution = try makePlan(target: .h265, videoCodec: "hevc", videoTag: tag)

            #expect(execution.ffmpegArguments.containsSequence(["-c:v", "copy"]))
            #expect(execution.ffmpegArguments.containsSequence(["-tag:v:0", "hvc1"]))
            #expect(!execution.ffmpegArguments.contains("libx265"))
        }

        for sourceCodec in ["h264", "vp9"] {
            let execution = try makePlan(target: .h265, videoCodec: sourceCodec)

            #expect(execution.ffmpegArguments.containsSequence(["-c:v", "libx265"]))
            #expect(execution.ffmpegArguments.containsSequence(["-tag:v:0", "hvc1"]))
            #expect(execution.ffmpegArguments.containsSequence(["-preset", "veryslow"]))
            #expect(execution.ffmpegArguments.containsSequence(["-crf", "18"]))
        }
    }

    @Test("Tagged HEVC remains copied when an external subtitle is embedded")
    func taggedHEVCWithExternalSubtitle() throws {
        let subtitle = ExternalSubtitle(
            url: URL(fileURLWithPath: "/media/movie.forced.srt"),
            language: "eng",
            role: .forced
        )
        let probe = try conversionProbe(streams: [
            ProbeStreamFixture(
                index: 0,
                codec: "hevc",
                type: "video",
                codecTag: "hvc1"
            )
        ])
        let plan = ConversionPlan(
            settings: conversionSettings(.h265),
            externalSubtitles: [subtitle]
        )

        let execution = try plan.makeExecutionPlan(
            input: URL(fileURLWithPath: "/media/movie.mkv"),
            output: URL(fileURLWithPath: "/tmp/output.mp4"),
            probe: probe
        )

        #expect(execution.ffmpegArguments.containsSequence(["-c:v", "copy"]))
        #expect(
            execution.ffmpegArguments.containsSequence([
                "-i", "/media/movie.forced.srt",
            ]))
        #expect(execution.ffmpegArguments.containsSequence(["-map", "1:0?"]))
        #expect(execution.ffmpegArguments.containsSequence(["-c:s", "mov_text"]))
    }

    private func makePlan(
        target: ConversionVideoCodec,
        videoCodec: String,
        videoTag: String? = nil,
    ) throws -> FFmpegExecutionPlan {
        let probe = try conversionProbe(streams: [
            ProbeStreamFixture(
                index: 0,
                codec: videoCodec,
                type: "video",
                codecTag: videoTag
            )
        ])
        return try ConversionPlan(
            settings: conversionSettings(target),
            externalSubtitles: []
        ).makeExecutionPlan(
            input: URL(fileURLWithPath: "/media/movie.mkv"),
            output: URL(fileURLWithPath: "/tmp/output.mp4"),
            probe: probe
        )
    }
}
