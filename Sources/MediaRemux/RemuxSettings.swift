import MediaProcessing

/// Configuration for rewriting a media container without re-encoding video.
public struct RemuxSettings: Sendable {
    /// Whether the output should be tagged for Apple-device compatibility.
    public let isAppleCompatible: Bool
    /// How the audio streams should be encoded in the remuxed output.
    public let audioEncoding: AudioEncoding
    /// How subtitle streams should be handled in the remuxed output.
    public let subtitleHandling: SubtitleHandling

    /// Creates remux settings.
    public init(
        isAppleCompatible: Bool,
        audioEncoding: AudioEncoding,
        subtitleHandling: SubtitleHandling
    ) {
        self.isAppleCompatible = isAppleCompatible
        self.audioEncoding = audioEncoding
        self.subtitleHandling = subtitleHandling
    }
}
