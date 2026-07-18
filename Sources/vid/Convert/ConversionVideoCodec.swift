import ArgumentParser

/// The Apple-compatible video codec produced by the `convert` command.
enum ConversionVideoCodec: String, CaseIterable, ExpressibleByArgument, Sendable {
    /// H.264/AVC video.
    case h264
    /// H.265/HEVC video tagged for Apple playback.
    case h265
}

/// Quality and compression settings for an on-demand media conversion.
struct MediaConversionSettings: Sendable {
    /// The target video codec.
    let videoCodec: ConversionVideoCodec
    /// The constant-rate factor passed to the selected video encoder.
    let crf: Int
    /// The encoder preset controlling compression efficiency and speed.
    let preset: String

    /// High-quality defaults intended for long-lived media libraries.
    static func highQuality(videoCodec: ConversionVideoCodec) -> Self {
        Self(videoCodec: videoCodec, crf: 18, preset: "veryslow")
    }
}
