import Foundation

/// Selects copy-versus-encode behavior and stream mappings for one conversion.
struct ConversionPlan: MediaOperationPlan {
    /// The filename suffix used only when replacement is not requested.
    var outputFilenameSuffix: String { "converted" }

    /// Quality, compression, and target-codec settings.
    let settings: MediaConversionSettings
    /// Matching external text subtitles available to the conversion.
    let externalSubtitles: [ExternalSubtitle]

    /// Builds the concrete FFmpeg invocation for a probed input.
    func makeExecutionPlan(
        input: URL,
        output: URL,
        probe: MediaProbe,
    ) throws -> FFmpegExecutionPlan {
        fatalError("Not Implemented")
    }
}
