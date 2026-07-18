import Foundation
import Testing

@testable import FFprobe
@testable import MediaProcessing

@Suite("FFmpeg plan support")
struct FFmpegPlanSupportTests {
    @Test("Inputs and maps preserve stream order")
    func inputsAndMaps() {
        let input = URL(fileURLWithPath: "/media/My Movie.mkv")
        #expect(FFmpegPlanSupport.inputArguments(input).suffix(2) == ["-i", input.path])

        var arguments: [String] = []
        FFmpegPlanSupport.appendMaps(
            video: mediaStream(index: 4, codec: "h264", type: "video"),
            audio: [mediaStream(index: 7, codec: "aac", type: "audio")],
            subtitles: [mediaStream(index: 9, codec: "subrip", type: "subtitle")],
            to: &arguments,
        )
        #expect(arguments == ["-map", "0:4", "-map", "0:7?", "-map", "0:9?"])
    }

    @Test("Video selection ignores cover art and reports missing video")
    func requiredVideo() throws {
        let probe = MediaProbe(streams: [
            mediaStream(index: 0, codec: "mjpeg", type: "video", attachedPicture: 1),
            mediaStream(index: 1, codec: "h264", type: "video", attachedPicture: 0),
        ])
        #expect(
            try FFmpegPlanSupport.requiredVideoStream(
                in: probe,
                input: URL(fileURLWithPath: "/movie.mkv")
            ).index == 1)

        do {
            _ = try FFmpegPlanSupport.requiredVideoStream(
                in: MediaProbe(streams: []),
                input: URL(fileURLWithPath: "/missing-video.mkv"),
            )
            Issue.record("A missing video stream should fail")
        } catch let error as MediaProcessingError {
            #expect(
                error.errorDescription == "'/missing-video.mkv' does not contain a video stream.")
        }
    }

    @Test("Subtitle modes select embedded and extracted streams")
    func subtitleHandling() {
        let probe = mediaProbe(includeBitmapSubtitle: true)
        #expect(
            FFmpegPlanSupport.subtitleStreams(in: probe, handling: .extractBitmap).map(\.index) == [
                2
            ])
        #expect(
            FFmpegPlanSupport.subtitleStreams(in: probe, handling: .textOnly).map(\.index) == [2])
        #expect(FFmpegPlanSupport.subtitleStreams(in: probe, handling: .none).isEmpty)
        #expect(
            FFmpegPlanSupport.bitmapSubtitles(in: probe, handling: .extractBitmap).map(\.index) == [
                3
            ])
        #expect(FFmpegPlanSupport.bitmapSubtitles(in: probe, handling: .textOnly).isEmpty)
        #expect(FFmpegPlanSupport.bitmapSubtitles(in: probe, handling: .none).isEmpty)

        var noSubtitles: [String] = []
        FFmpegPlanSupport.appendSubtitleOutputOptions(for: [], to: &noSubtitles)
        #expect(noSubtitles == ["-sn"])
        var textSubtitles: [String] = []
        FFmpegPlanSupport.appendSubtitleOutputOptions(
            for: probe.textSubtitleStreams, to: &textSubtitles)
        #expect(textSubtitles == ["-c:s", "mov_text"])
    }

    @Test("Audio encodings and Apple tags cover every codec")
    func audioOptions() {
        var arguments: [String] = []
        FFmpegPlanSupport.appendAudioEncoding(.aac(bitrate: "192k"), to: &arguments)
        FFmpegPlanSupport.appendAudioEncoding(.copy, to: &arguments)
        FFmpegPlanSupport.appendAudioEncoding(.eac3(bitrate: "640k"), to: &arguments)
        #expect(
            arguments == [
                "-c:a", "aac", "-b:a", "192k",
                "-c:a", "copy",
                "-c:a", "eac3", "-b:a", "640k",
            ])

        let streams = [
            mediaStream(index: 1, codec: "ac3", type: "audio"),
            mediaStream(index: 2, codec: "eac3", type: "audio"),
            mediaStream(index: 3, codec: "aac", type: "audio"),
        ]
        var copied: [String] = []
        FFmpegPlanSupport.appendAudioTags(sourceStreams: streams, encoding: .copy, to: &copied)
        #expect(copied == ["-tag:a:0", "ac-3", "-tag:a:1", "ec-3"])

        var encoded: [String] = []
        FFmpegPlanSupport.appendAudioTags(
            sourceStreams: streams,
            encoding: .eac3(bitrate: "320k"),
            to: &encoded,
        )
        #expect(
            encoded == [
                "-tag:a:0", "ec-3", "-tag:a:1", "ec-3", "-tag:a:2", "ec-3",
            ])

        var aac: [String] = []
        FFmpegPlanSupport.appendAudioTags(
            sourceStreams: streams,
            encoding: .aac(bitrate: "192k"),
            to: &aac,
        )
        #expect(aac.isEmpty)
    }
}
