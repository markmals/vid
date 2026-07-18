/// How an output's audio streams should be encoded.
public enum AudioEncoding: Sendable {
    /// Re-encode audio streams to AAC at the given bitrate (for example `192k`).
    case aac(bitrate: String)
    /// Copy source audio streams without re-encoding.
    case copy
    /// Re-encode audio streams to Enhanced AC-3 (E-AC-3) at the given bitrate.
    case eac3(bitrate: String)
}

/// How an output's subtitle streams should be handled.
public enum SubtitleHandling: Sendable {
    /// Extract bitmap subtitles to sidecar files rather than embedding them.
    case extractBitmap
    /// Drop all subtitle streams from the output.
    case none
    /// Keep only text-based subtitle streams, converting them as needed.
    case textOnly
}
