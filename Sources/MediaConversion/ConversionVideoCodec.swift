/// The Apple-compatible video codec produced by the `convert` command.
public enum ConversionVideoCodec: String, CaseIterable, Sendable {
    /// H.264/AVC video.
    case h264
    /// H.265/HEVC video tagged for Apple playback.
    case h265
}

/// Quality and compression settings for an on-demand media conversion.
public struct MediaConversionSettings: Sendable {
    /// The target video codec.
    public let videoCodec: ConversionVideoCodec
    /// The constant-rate factor passed to the selected video encoder.
    public let crf: Int
    /// The encoder preset controlling compression efficiency and speed.
    public let preset: String

    /// Creates conversion settings.
    public init(videoCodec: ConversionVideoCodec, crf: Int, preset: String) {
        self.videoCodec = videoCodec
        self.crf = crf
        self.preset = preset
    }

    /// High-quality defaults intended for long-lived media libraries.
    public static func highQuality(videoCodec: ConversionVideoCodec) -> Self {
        Self(videoCodec: videoCodec, crf: 18, preset: "veryslow")
    }
}
