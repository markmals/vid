import Foundation

/// A subtitle track's role when choosing the single track embedded in an MP4.
enum ConversionSubtitleRole: Int, Comparable, Sendable {
    /// Dialogue required to understand otherwise untranslated speech.
    case forced
    /// The source's preferred default subtitle track.
    case defaultTrack
    /// Subtitles for deaf and hard-of-hearing viewers.
    case sdh
    /// A subtitle without a preferred role.
    case unspecified

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A text subtitle file stored beside a video.
struct ExternalSubtitle: Equatable, Sendable {
    /// The subtitle file URL.
    let url: URL
    /// The language inferred from the filename, when present.
    let language: String?
    /// The role inferred from the filename.
    let role: ConversionSubtitleRole
}

/// Finds supported subtitle files whose basename matches a video.
struct ExternalSubtitleDiscovery: Sendable {
    /// Finds matching text subtitle sidecars in the video's directory.
    func subtitles(matching video: URL) throws -> [ExternalSubtitle] {
        fatalError("Not Implemented")
    }
}
