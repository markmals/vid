import FFprobe
import Foundation
import MediaProcessing

/// A media operation plan that adds an external subtitle file as a new text
/// track while preserving each supported source stream.
public struct AddSubtitlePlan: MediaOperationPlan {
    /// The filename suffix (`subtitled`) applied when the default output would
    /// collide with the source file.
    public var outputFilenameSuffix: String { "subtitled" }

    /// The external subtitle file to add as a new track.
    public let subtitle: URL

    /// The ISO language code recorded on the added subtitle track.
    public let language: String

    /// The human-readable title recorded on the added subtitle track.
    public let title: String

    /// Creates an operation that adds one external subtitle track.
    public init(subtitle: URL, language: String, title: String) {
        self.subtitle = subtitle
        self.language = language
        self.title = title
    }

    /// Builds the FFmpeg execution plan that muxes in the external subtitle.
    ///
    /// The source video and audio are copied. Existing text subtitles and the
    /// external subtitle are encoded as `mov_text`; bitmap subtitles are
    /// extracted as sidecars. HEVC video is tagged `hvc1`.
    ///
    /// - Parameters:
    ///   - input: The source media file to add the subtitle to.
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
        let audio = probe.audioStreams
        let existingSubtitles = probe.textSubtitleStreams

        var arguments = FFmpegPlanSupport.inputArguments(for: input)
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

        return FFmpegExecutionPlan(
            ffmpegArguments: arguments,
            subtitleExtractions: FFmpegPlanSupport.bitmapSubtitleExtractions(
                in: probe,
                handling: .extractBitmap,
                input: input
            )
        )
    }
}
