import Foundation

struct EncodePlan: MediaPlan {
    let operationName = "encoded"
    let settings: EncodeSettings

    func makeProcessingPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> MediaProcessingPlan {
        let video = try FFmpegPlanSupport.requireVideo(probe, input: input)
        let audio = probe.audioStreams.filter { stream in
            guard let language = stream.language else {
                return true
            }
            return !settings.excludedAudioLanguages.contains(language)
        }
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
        arguments += [
            "-c:v", "libx265",
            "-tag:v:0", "hvc1",
            "-crf", String(settings.crf),
            "-preset", settings.preset,
        ]
        FFmpegPlanSupport.appendAudioEncoding(settings.audioEncoding, to: &arguments)
        FFmpegPlanSupport.appendTextSubtitleCodec(when: subtitles, to: &arguments)
        arguments += ["-map_metadata", "0"]
        FFmpegPlanSupport.appendAudioTags(
            sourceStreams: audio,
            encoding: settings.audioEncoding,
            to: &arguments,
        )

        if settings.normalizeDispositions {
            Self.appendNormalizedDispositions(
                audio: audio,
                subtitles: subtitles,
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

    private static func appendNormalizedDispositions(
        audio: [MediaStream],
        subtitles: [MediaStream],
        to arguments: inout [String],
    ) {
        if !audio.isEmpty {
            arguments += ["-disposition:a", "0", "-disposition:a:0", "default"]
        }
        if !subtitles.isEmpty {
            arguments += ["-disposition:s", "0"]
        }
        if let englishSubtitleIndex = subtitles.firstIndex(where: { $0.language == "eng" }) {
            arguments += ["-disposition:s:\(englishSubtitleIndex)", "default"]
        }
    }
}
