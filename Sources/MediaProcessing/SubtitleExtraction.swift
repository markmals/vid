import FFprobe
import Foundation

/// Encoding applied when a subtitle track is written beside a converted video.
public enum SubtitleSidecarEncoding: Sendable {
    /// Preserve the source subtitle codec.
    case copy
    /// Convert a text subtitle to SubRip.
    case srt

    /// The FFmpeg codec token used to write the sidecar.
    public var ffmpegCodecName: String {
        switch self {
        case .copy: "copy"
        case .srt: "srt"
        }
    }
}

/// A subtitle stream that FFmpeg must stage as a sidecar before output commit.
public struct SubtitleExtractionPlan: Sendable {
    /// The media or subtitle file containing the source stream.
    public let inputURL: URL
    /// The source stream metadata and index.
    public let stream: MediaStream
    /// The final sidecar filename, including its extension.
    public let outputFilename: String
    /// Whether FFmpeg copies the stream or converts it to SubRip.
    public let encoding: SubtitleSidecarEncoding

    /// Creates a sidecar extraction plan.
    public init(
        inputURL: URL,
        stream: MediaStream,
        outputFilename: String,
        encoding: SubtitleSidecarEncoding
    ) {
        self.inputURL = inputURL
        self.stream = stream
        self.outputFilename = outputFilename
        self.encoding = encoding
    }
}
