import MediaProcessing

/// Configuration for re-encoding video and remapping its related streams.
public struct EncodeSettings: Sendable {
    /// How the audio streams should be encoded in the output.
    public let audioEncoding: AudioEncoding
    /// The constant-rate factor controlling the video quality and size tradeoff.
    public let crf: Int
    /// Audio languages, by language code, to exclude from the output.
    public let excludedAudioLanguages: Set<String>
    /// Whether stream dispositions should be normalized in the output.
    public let shouldNormalizeDispositions: Bool
    /// The encoder preset controlling the speed and compression tradeoff.
    public let preset: String
    /// How subtitle streams should be handled in the output.
    public let subtitleHandling: SubtitleHandling

    /// Creates encode settings.
    public init(
        audioEncoding: AudioEncoding,
        crf: Int,
        excludedAudioLanguages: Set<String>,
        shouldNormalizeDispositions: Bool,
        preset: String,
        subtitleHandling: SubtitleHandling
    ) {
        self.audioEncoding = audioEncoding
        self.crf = crf
        self.excludedAudioLanguages = excludedAudioLanguages
        self.shouldNormalizeDispositions = shouldNormalizeDispositions
        self.preset = preset
        self.subtitleHandling = subtitleHandling
    }
}
