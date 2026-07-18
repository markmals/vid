import FFprobe
import Foundation
import MediaProcessing

/// A media operation plan that re-encodes the video to HEVC while remapping
/// audio and subtitle streams according to its settings.
public struct EncodePlan: MediaOperationPlan {
    /// The filename suffix (`encoded`) applied when the default output would
    /// collide with the source file.
    public var outputFilenameSuffix: String { "encoded" }

    /// The settings controlling audio, subtitle, and disposition handling.
    public let settings: EncodeSettings

    /// Creates an encode operation plan.
    public init(settings: EncodeSettings) {
        self.settings = settings
    }

    /// Builds the FFmpeg execution plan that re-encodes the source to HEVC.
    ///
    /// Audio streams whose language is excluded by the settings are dropped,
    /// subtitles are selected per the settings' handling mode, the video is
    /// encoded with `libx265` tagged `hvc1`, and stream dispositions are
    /// normalized when requested.
    ///
    /// - Parameters:
    ///   - input: The source media file to encode.
    ///   - output: The destination file path written by FFmpeg.
    ///   - probe: The probe describing the source streams.
    /// - Returns: The execution plan with the FFmpeg arguments and any bitmap
    ///   subtitles to extract.
    /// - Throws: `MediaProcessingError.noVideoStream(path:)` when `input` has no
    ///   video stream.
    public func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> FFmpegExecutionPlan {
        let video = try FFmpegPlanSupport.requiredVideoStream(in: probe, input: input)
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

        var arguments = FFmpegPlanSupport.inputArguments(for: input)
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
        FFmpegPlanSupport.appendSubtitleOutputOptions(for: subtitles, to: &arguments)
        arguments += ["-map_metadata", "0"]
        FFmpegPlanSupport.appendAudioTags(
            sourceStreams: audio,
            encoding: settings.audioEncoding,
            to: &arguments,
        )

        if settings.shouldNormalizeDispositions {
            Self.appendNormalizedDispositions(
                audio: audio,
                subtitles: subtitles,
                to: &arguments,
            )
        }

        arguments += ["-movflags", "+faststart", output.path]
        return FFmpegExecutionPlan(
            ffmpegArguments: arguments,
            subtitleExtractions: FFmpegPlanSupport.bitmapSubtitleExtractions(
                in: probe,
                handling: settings.subtitleHandling,
                input: input
            )
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
