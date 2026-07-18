import Foundation
import Testing

@testable import vid

@Suite("Media operation plans")
struct OperationPlanTests {
    @Test("Remux supports every subtitle and audio mode")
    func remuxVariants() throws {
        let input = URL(fileURLWithPath: "/media/input.mkv")
        let output = URL(fileURLWithPath: "/media/output.mp4")
        let probe = mediaProbe(videoCodec: "h264", audioCodec: "ac3", includeBitmapSubtitle: true)

        let plan = RemuxPlan(
            outputFilenameSuffix: "remuxed",
            settings: RemuxSettings(
                isAppleCompatible: false,
                audioEncoding: .aac(bitrate: "192k"),
                subtitleHandling: .none,
            ),
        )
        let execution = try plan.makeExecutionPlan(input: input, output: output, probe: probe)
        #expect(execution.ffmpegArguments.containsSequence(["-c:v", "copy"]))
        #expect(execution.ffmpegArguments.containsSequence(["-c:a", "aac", "-b:a", "192k"]))
        #expect(execution.ffmpegArguments.contains("-sn"))
        #expect(!execution.ffmpegArguments.contains("hvc1"))
        #expect(execution.bitmapSubtitlesToExtract.isEmpty)
    }

    @Test("Encoding keeps untagged audio and handles empty dispositions")
    func encodeVariants() throws {
        let probe = MediaProbe(streams: [
            mediaStream(index: 0, codec: "h264", type: "video"),
            mediaStream(index: 1, codec: "aac", type: "audio"),
            mediaStream(index: 2, codec: "aac", type: "audio", language: "RUS"),
            mediaStream(index: 3, codec: "subrip", type: "subtitle", language: "spa"),
        ])
        let plan = EncodePlan(
            settings: EncodeSettings(
                audioEncoding: .copy,
                crf: 18,
                excludedAudioLanguages: ["rus"],
                shouldNormalizeDispositions: true,
                preset: "slow",
                subtitleHandling: .textOnly,
            ))
        #expect(plan.outputFilenameSuffix == "encoded")

        let execution = try plan.makeExecutionPlan(
            input: URL(fileURLWithPath: "/input.mkv"),
            output: URL(fileURLWithPath: "/output.mp4"),
            probe: probe,
        )
        #expect(execution.ffmpegArguments.containsSequence(["-map", "0:1?"]))
        #expect(!execution.ffmpegArguments.containsSequence(["-map", "0:2?"]))
        #expect(execution.ffmpegArguments.containsSequence(["-disposition:a:0", "default"]))
        #expect(execution.ffmpegArguments.containsSequence(["-disposition:s", "0"]))
        #expect(!execution.ffmpegArguments.contains("-disposition:s:0"))

        let videoOnly = EncodePlan(
            settings: EncodeSettings(
                audioEncoding: .copy,
                crf: 23,
                excludedAudioLanguages: [],
                shouldNormalizeDispositions: true,
                preset: "medium",
                subtitleHandling: .none,
            ))
        let videoOnlyExecution = try videoOnly.makeExecutionPlan(
            input: URL(fileURLWithPath: "/input.mkv"),
            output: URL(fileURLWithPath: "/output.mp4"),
            probe: MediaProbe(streams: [mediaStream(index: 0, codec: "h264", type: "video")]),
        )
        #expect(!videoOnlyExecution.ffmpegArguments.contains("-disposition:a"))
        #expect(!videoOnlyExecution.ffmpegArguments.contains("-disposition:s"))
    }

    @Test("Repair keeps only the first audio stream")
    func repairPlan() throws {
        let plan = RepairPlan()
        #expect(plan.outputFilenameSuffix == "repaired")
        let execution = try plan.makeExecutionPlan(
            input: URL(fileURLWithPath: "/input.mkv"),
            output: URL(fileURLWithPath: "/output.mp4"),
            probe: MediaProbe(streams: [
                mediaStream(index: 0, codec: "h264", type: "video"),
                mediaStream(index: 1, codec: "aac", type: "audio"),
                mediaStream(index: 2, codec: "aac", type: "audio"),
            ]),
        )
        #expect(execution.ffmpegArguments.containsSequence(["-map", "0:1?"]))
        #expect(!execution.ffmpegArguments.containsSequence(["-map", "0:2?"]))
        #expect(execution.ffmpegArguments.containsSequence(["-vf", "yadif,format=yuv420p"]))
        #expect(execution.bitmapSubtitlesToExtract.isEmpty)
    }

    @Test("Adding subtitles maps metadata and tags only HEVC video")
    func addSubtitlePlan() throws {
        let input = URL(fileURLWithPath: "/input.mkv")
        let output = URL(fileURLWithPath: "/output.mp4")
        let subtitle = URL(fileURLWithPath: "/input.srt")

        let hevc = AddSubtitlePlan(subtitle: subtitle, language: "fra", title: "French")
        #expect(hevc.outputFilenameSuffix == "subtitled")
        let hevcExecution = try hevc.makeExecutionPlan(
            input: input,
            output: output,
            probe: mediaProbe(videoCodec: "hevc", audioCodec: "eac3", includeBitmapSubtitle: true),
        )
        #expect(hevcExecution.ffmpegArguments.containsSequence(["-map", "1:0"]))
        #expect(
            hevcExecution.ffmpegArguments.containsSequence([
                "-metadata:s:s:1", "language=fra",
            ]))
        #expect(hevcExecution.ffmpegArguments.containsSequence(["-tag:v:0", "hvc1"]))
        #expect(hevcExecution.ffmpegArguments.containsSequence(["-tag:a:0", "ec-3"]))
        #expect(hevcExecution.bitmapSubtitlesToExtract.map(\.index) == [3])

        let h264Execution = try hevc.makeExecutionPlan(
            input: input,
            output: output,
            probe: mediaProbe(videoCodec: "h264", includeTextSubtitle: false),
        )
        #expect(!h264Execution.ffmpegArguments.contains("hvc1"))
        #expect(
            h264Execution.ffmpegArguments.containsSequence([
                "-metadata:s:s:0", "title=French",
            ]))
    }
}
