enum AudioEncoding: Sendable {
    case aac(bitrate: String)
    case copy
    case eac3(bitrate: String)
}

enum SubtitleHandling: Sendable {
    case extractBitmap
    case none
    case textOnly
}

struct RemuxSettings: Sendable {
    let appleCompatible: Bool
    let audioEncoding: AudioEncoding
    let subtitleHandling: SubtitleHandling
}

struct EncodeSettings: Sendable {
    let audioEncoding: AudioEncoding
    let crf: Int
    let excludedAudioLanguages: Set<String>
    let normalizeDispositions: Bool
    let preset: String
    let subtitleHandling: SubtitleHandling
}
