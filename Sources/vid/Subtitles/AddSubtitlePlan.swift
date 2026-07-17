import Foundation

struct AddSubtitlePlan: MediaPlan {
    let operationName = "subbed"
    let subtitle: URL
    let language: String
    let title: String

    func makeProcessingPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> MediaProcessingPlan {
        let video = try FFmpegPlanSupport.requireVideo(probe, input: input)
        let audio = probe.audioStreams
        let existingSubtitles = probe.textSubtitleStreams

        var arguments = FFmpegPlanSupport.inputArguments(input)
        arguments += ["-i", subtitle.path]
        FFmpegPlanSupport.appendMaps(
            video: video,
            audio: audio,
            subtitles: existingSubtitles,
            to: &arguments,
        )
        arguments += [
            "-map", "1:0",
            "-c:v", "copy",
            "-c:a", "copy",
            "-c:s", "mov_text",
            "-map_metadata", "0",
        ]

        let addedSubtitleIndex = existingSubtitles.count
        arguments += [
            "-metadata:s:s:\(addedSubtitleIndex)", "language=\(language)",
            "-metadata:s:s:\(addedSubtitleIndex)", "title=\(title)",
        ]

        if video.codecName == "hevc" {
            arguments += ["-tag:v:0", "hvc1"]
        }
        FFmpegPlanSupport.appendAudioTags(
            sourceStreams: audio,
            encoding: .copy,
            to: &arguments,
        )
        arguments += ["-movflags", "+faststart", output.path]

        return MediaProcessingPlan(
            ffmpegArguments: arguments,
            bitmapSubtitlesToExtract: probe.bitmapSubtitleStreams,
        )
    }
}
