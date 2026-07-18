import Foundation
import Testing

@testable import vid

@Suite("Conversion audio and subtitle plans")
struct ConversionStreamPlanTests {
    @Test("Audio copies AAC and E-AC-3 and encodes other codecs by channel count")
    func audioSelection() throws {
        let probe = try conversionProbe(streams: [
            ProbeStreamFixture(index: 0, codec: "h264", type: "video"),
            ProbeStreamFixture(index: 1, codec: "aac", type: "audio", channels: 2),
            ProbeStreamFixture(index: 2, codec: "eac3", type: "audio", channels: 6),
            ProbeStreamFixture(index: 3, codec: "ac3", type: "audio", channels: 2),
            ProbeStreamFixture(index: 4, codec: "dts", type: "audio", channels: 6),
        ])

        let arguments = try executionPlan(probe: probe).ffmpegArguments

        #expect(arguments.containsSequence(["-c:a:0", "copy"]))
        #expect(arguments.containsSequence(["-c:a:1", "copy"]))
        #expect(arguments.containsSequence(["-tag:a:1", "ec-3"]))
        #expect(arguments.containsSequence(["-c:a:2", "aac", "-b:a:2", "192k"]))
        #expect(arguments.containsSequence(["-c:a:3", "eac3", "-b:a:3", "640k"]))
        #expect(arguments.containsSequence(["-tag:a:3", "ec-3"]))
    }

    @Test("Only the highest-priority compatible text subtitle is embedded")
    func preferredEmbeddedSubtitle() throws {
        let forcedProbe = try subtitleProbe(
            defaultIndex: 2,
            sdhIndex: 3,
            forcedIndex: 4
        )
        let forcedArguments = try executionPlan(probe: forcedProbe).ffmpegArguments
        #expect(forcedArguments.containsSequence(["-map", "0:4?"]))
        #expect(!forcedArguments.containsSequence(["-map", "0:2?"]))
        #expect(!forcedArguments.containsSequence(["-map", "0:3?"]))
        #expect(forcedArguments.containsSequence(["-c:s", "mov_text"]))

        let defaultProbe = try subtitleProbe(defaultIndex: 2, sdhIndex: 3)
        let defaultArguments = try executionPlan(probe: defaultProbe).ffmpegArguments
        #expect(defaultArguments.containsSequence(["-map", "0:2?"]))
        #expect(!defaultArguments.containsSequence(["-map", "0:3?"]))

        let sdhProbe = try subtitleProbe(sdhIndex: 3)
        let sdhArguments = try executionPlan(probe: sdhProbe).ffmpegArguments
        #expect(sdhArguments.containsSequence(["-map", "0:3?"]))
    }

    @Test("Bitmap subtitles are excluded from MP4 and scheduled for extraction")
    func bitmapSubtitleExtraction() throws {
        let probe = try conversionProbe(streams: [
            ProbeStreamFixture(index: 0, codec: "h264", type: "video"),
            ProbeStreamFixture(
                index: 5,
                codec: "hdmv_pgs_subtitle",
                type: "subtitle",
                language: "eng"
            ),
            ProbeStreamFixture(index: 6, codec: "dvd_subtitle", type: "subtitle"),
            ProbeStreamFixture(index: 7, codec: "dvb_subtitle", type: "subtitle"),
            ProbeStreamFixture(index: 8, codec: "xsub", type: "subtitle"),
        ])

        let execution = try executionPlan(probe: probe)

        #expect(!execution.ffmpegArguments.containsSequence(["-map", "0:5?"]))
        #expect(execution.subtitleExtractions.map(\.stream.index) == [5, 6, 7, 8])
    }

    private func executionPlan(probe: MediaProbe) throws -> FFmpegExecutionPlan {
        try ConversionPlan(
            settings: conversionSettings(.h265),
            externalSubtitles: []
        ).makeExecutionPlan(
            input: URL(fileURLWithPath: "/media/movie.mkv"),
            output: URL(fileURLWithPath: "/tmp/output.mp4"),
            probe: probe
        )
    }

    private func subtitleProbe(
        defaultIndex: Int? = nil,
        sdhIndex: Int? = nil,
        forcedIndex: Int? = nil,
    ) throws -> MediaProbe {
        var streams = [ProbeStreamFixture(index: 0, codec: "h264", type: "video")]
        if let defaultIndex {
            streams.append(
                ProbeStreamFixture(
                    index: defaultIndex,
                    codec: "subrip",
                    type: "subtitle",
                    language: "eng",
                    isDefault: true
                ))
        }
        if let sdhIndex {
            streams.append(
                ProbeStreamFixture(
                    index: sdhIndex,
                    codec: "ass",
                    type: "subtitle",
                    language: "eng",
                    title: "English SDH",
                    isHearingImpaired: true
                ))
        }
        if let forcedIndex {
            streams.append(
                ProbeStreamFixture(
                    index: forcedIndex,
                    codec: "webvtt",
                    type: "subtitle",
                    language: "eng",
                    isForced: true
                ))
        }
        return try conversionProbe(streams: streams)
    }
}
