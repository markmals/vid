/// How an output's audio streams should be encoded.
enum AudioEncoding: Sendable {
    /// Re-encode audio streams to AAC at the given bitrate (for example `192k`).
    case aac(bitrate: String)
    /// Copy source audio streams without re-encoding.
    case copy
    /// Re-encode audio streams to Enhanced AC-3 (E-AC-3) at the given bitrate.
    case eac3(bitrate: String)
}

/// How an output's subtitle streams should be handled.
enum SubtitleHandling: Sendable {
    /// Extract bitmap subtitles to sidecar files rather than embedding them.
    case extractBitmap
    /// Drop all subtitle streams from the output.
    case none
    /// Keep only text-based subtitle streams, converting them as needed.
    case textOnly
}

/// The configuration that drives a remux operation, which rewrites a container
/// without re-encoding video.
struct RemuxSettings: Sendable {
    /// Whether the output should be tagged for Apple-device compatibility.
    let isAppleCompatible: Bool
    /// How the audio streams should be encoded in the remuxed output.
    let audioEncoding: AudioEncoding
    /// How subtitle streams should be handled in the remuxed output.
    let subtitleHandling: SubtitleHandling
}

/// The configuration that drives an encode operation, which re-encodes video.
struct EncodeSettings: Sendable {
    /// How the audio streams should be encoded in the output.
    let audioEncoding: AudioEncoding
    /// The Constant Rate Factor controlling the video quality/size tradeoff.
    let crf: Int
    /// Audio languages, by language code, to exclude from the output.
    let excludedAudioLanguages: Set<String>
    /// Whether stream dispositions should be normalized in the output.
    let shouldNormalizeDispositions: Bool
    /// The encoder preset controlling the speed/compression tradeoff.
    let preset: String
    /// How subtitle streams should be handled in the output.
    let subtitleHandling: SubtitleHandling
}
