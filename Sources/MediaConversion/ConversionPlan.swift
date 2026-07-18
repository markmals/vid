import FFprobe
import Foundation
import MediaProcessing

/// Selects copy-versus-encode behavior and stream mappings for one conversion.
public struct ConversionPlan: MediaOperationPlan {
    /// The filename suffix used only when replacement is not requested.
    public var outputFilenameSuffix: String { "converted" }

    /// Quality, compression, and target-codec settings.
    public let settings: MediaConversionSettings
    /// Matching external text subtitles available to the conversion.
    public let externalSubtitles: [ExternalSubtitle]

    /// Creates a conversion plan.
    public init(
        settings: MediaConversionSettings,
        externalSubtitles: [ExternalSubtitle] = []
    ) {
        self.settings = settings
        self.externalSubtitles = externalSubtitles
    }

    /// Builds a stream-specific FFmpeg invocation and subtitle sidecar plan.
    public func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe
    ) throws -> FFmpegExecutionPlan {
        let video = try FFmpegPlanSupport.requiredVideoStream(in: probe, input: input)
        let subtitleSelection = ConversionSubtitleSelection(
            input: input,
            probe: probe,
            externalSubtitles: externalSubtitles
        )
        var arguments = FFmpegPlanSupport.inputArguments(for: input)
        appendExternalSubtitleInput(subtitleSelection.selected, to: &arguments)
        FFmpegPlanSupport.appendMaps(
            video: video,
            audio: probe.audioStreams,
            subtitles: [],
            to: &arguments
        )
        appendSelectedSubtitleMap(subtitleSelection.selected, to: &arguments)
        appendVideoEncoding(for: video, to: &arguments)
        appendAudioEncoding(for: probe.audioStreams, to: &arguments)
        appendSubtitleEncoding(subtitleSelection.selected, to: &arguments)
        arguments += ["-map_metadata", "0", "-movflags", "+faststart", output.path]

        return FFmpegExecutionPlan(
            ffmpegArguments: arguments,
            subtitleExtractions: subtitleSelection.extractions
        )
    }

    private func appendVideoEncoding(
        for video: MediaStream,
        to arguments: inout [String]
    ) {
        let shouldCopy: Bool
        switch settings.videoCodec {
        case .h264:
            shouldCopy = video.codecName == "h264" || video.codecName == "hevc"
        case .h265:
            shouldCopy = video.codecName == "hevc"
        }

        if shouldCopy {
            arguments += ["-c:v", "copy"]
        } else {
            let encoder = settings.videoCodec == .h264 ? "libx264" : "libx265"
            arguments += [
                "-c:v", encoder,
                "-preset", settings.preset,
                "-crf", String(settings.crf),
            ]
        }

        if video.codecName == "hevc" || settings.videoCodec == .h265 {
            if video.codecName == "hevc", video.codecTagString != "hvc1" {
                arguments += ["-bsf:v", "hevc_metadata=aud=insert"]
            }
            arguments += ["-tag:v:0", "hvc1"]
        }
    }

    private func appendAudioEncoding(
        for streams: [MediaStream],
        to arguments: inout [String]
    ) {
        for (outputIndex, stream) in streams.enumerated() {
            switch stream.codecName {
            case "aac":
                arguments += ["-c:a:\(outputIndex)", "copy"]
            case "eac3":
                arguments += [
                    "-c:a:\(outputIndex)", "copy",
                    "-tag:a:\(outputIndex)", "ec-3",
                ]
            default:
                if (stream.channels ?? 2) > 2 {
                    arguments += [
                        "-c:a:\(outputIndex)", "eac3",
                        "-b:a:\(outputIndex)", "640k",
                        "-tag:a:\(outputIndex)", "ec-3",
                    ]
                } else {
                    arguments += [
                        "-c:a:\(outputIndex)", "aac",
                        "-b:a:\(outputIndex)", "192k",
                    ]
                }
            }
        }
    }

    private func appendExternalSubtitleInput(
        _ selected: SelectedConversionSubtitle?,
        to arguments: inout [String]
    ) {
        guard case .external(let subtitle) = selected else {
            return
        }
        arguments += ["-i", subtitle.url.path]
    }

    private func appendSelectedSubtitleMap(
        _ selected: SelectedConversionSubtitle?,
        to arguments: inout [String]
    ) {
        switch selected {
        case .embedded(let stream):
            arguments += ["-map", "0:\(stream.index)?"]
        case .external:
            arguments += ["-map", "1:0?"]
        case nil:
            break
        }
    }

    private func appendSubtitleEncoding(
        _ selected: SelectedConversionSubtitle?,
        to arguments: inout [String]
    ) {
        guard let selected else {
            arguments += ["-sn"]
            return
        }
        arguments += ["-c:s", "mov_text"]
        guard case .external(let subtitle) = selected, let language = subtitle.language else {
            return
        }
        arguments += ["-metadata:s:s:0", "language=\(language)"]
    }
}
