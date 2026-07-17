import Foundation

/// A media operation plan that repackages the source into an MP4 container
/// without re-encoding the video, optionally applying Apple-compatible tagging.
struct RemuxPlan: MediaOperationPlan {
    /// The filename suffix applied when the default output would collide with
    /// the source file (`remuxed` or `tagged`, chosen by the caller).
    let outputFilenameSuffix: String

    /// The settings controlling Apple compatibility, audio, and subtitle handling.
    let settings: RemuxSettings

    /// Builds the FFmpeg execution plan that remuxes the source to MP4.
    ///
    /// The video stream is copied; audio and subtitles are mapped per the
    /// settings. When Apple compatibility is requested, HEVC video gains an
    /// access-unit-delimiter bitstream filter and `hvc1` tag, and audio streams
    /// receive Apple codec tags.
    ///
    /// - Parameters:
    ///   - input: The source media file to remux.
    ///   - output: The destination file path written by FFmpeg.
    ///   - probe: The probe describing the source streams.
    /// - Returns: The execution plan with the FFmpeg arguments and any bitmap
    ///   subtitles to extract.
    /// - Throws: ``VidError/noVideoStream(path:)`` when `input` has no video stream.
    func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> FFmpegExecutionPlan {
        let video = try FFmpegPlanSupport.requiredVideoStream(in: probe, input: input)
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
        FFmpegPlanSupport.appendSubtitleOutputOptions(for: subtitles, to: &arguments)
        arguments += ["-map_metadata", "0"]

        if settings.isAppleCompatible {
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
        return FFmpegExecutionPlan(
            ffmpegArguments: arguments,
            bitmapSubtitlesToExtract: FFmpegPlanSupport.bitmapSubtitles(
                in: probe,
                handling: settings.subtitleHandling,
            ),
        )
    }
}
