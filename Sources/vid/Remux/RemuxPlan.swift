import Foundation

struct RemuxPlan: MediaPlan {
    let operationName: String
    let settings: RemuxSettings

    func makeProcessingPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> MediaProcessingPlan {
        let video = try FFmpegPlanSupport.requireVideo(probe, input: input)
        let audio = probe.audioStreams
        let subtitles = FFmpegPlanSupport.subtitleStreams(
            in: probe,
            handling: settings.subtitleHandling,
        )

        var arguments = FFmpegPlanSupport.inputArguments(input)
        FFmpegPlanSupport.appendMaps(
            video: video,
            audio: audio,
            subtitles: subtitles,
            to: &arguments,
        )
        arguments += ["-c:v", "copy"]
        FFmpegPlanSupport.appendAudioEncoding(settings.audioEncoding, to: &arguments)
        FFmpegPlanSupport.appendTextSubtitleCodec(when: subtitles, to: &arguments)
        arguments += ["-map_metadata", "0"]

        if settings.appleCompatible {
            if video.codecName == "hevc" {
                arguments += ["-bsf:v", "hevc_metadata=aud=insert", "-tag:v:0", "hvc1"]
            }
            FFmpegPlanSupport.appendAudioTags(
                sourceStreams: audio,
                encoding: settings.audioEncoding,
                to: &arguments,
            )
        }

        arguments += ["-movflags", "+faststart", output.path]
        return MediaProcessingPlan(
            ffmpegArguments: arguments,
            bitmapSubtitlesToExtract: FFmpegPlanSupport.bitmapSubtitles(
                in: probe,
                handling: settings.subtitleHandling,
            ),
        )
    }
}
