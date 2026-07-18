import Foundation

/// Encoding applied when a subtitle track is written beside a converted video.
enum SubtitleSidecarEncoding: Sendable {
    /// Preserve the source subtitle codec.
    case copy
    /// Convert a text subtitle to SubRip.
    case srt

    var ffmpegCodecName: String {
        switch self {
        case .copy: "copy"
        case .srt: "srt"
        }
    }
}

/// A subtitle stream that FFmpeg must stage as a sidecar before output commit.
struct SubtitleExtractionPlan: Sendable {
    /// The media or subtitle file containing the source stream.
    let inputURL: URL
    /// The source stream metadata and index.
    let stream: MediaStream
    /// The final sidecar filename, including its extension.
    let outputFilename: String
    /// Whether FFmpeg copies the stream or converts it to SubRip.
    let encoding: SubtitleSidecarEncoding
}
