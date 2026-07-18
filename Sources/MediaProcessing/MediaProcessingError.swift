import Foundation

/// Errors produced while planning, staging, and committing media output.
public enum MediaProcessingError: Error, LocalizedError, Sendable {
    /// FFmpeg completed without producing a non-empty output file.
    case emptyOutput(path: String)
    /// The requested output directory is missing or is not a directory.
    case invalidOutputDirectory(path: String)
    /// The supplied output options cannot be satisfied together.
    case incompatibleOutputOptions(reason: String)
    /// The input does not contain a usable video stream.
    case noVideoStream(path: String)
    /// An output already exists and replacement was not requested.
    case outputExists(path: String)

    /// A concise description suitable for command-line display.
    public var errorDescription: String? {
        switch self {
        case .emptyOutput(let path):
            "FFmpeg did not create a non-empty output at '\(path)'."
        case .invalidOutputDirectory(let path):
            "The output directory '\(path)' does not exist or is not a directory."
        case .incompatibleOutputOptions(let reason):
            "Incompatible output options: \(reason)"
        case .noVideoStream(let path):
            "'\(path)' does not contain a video stream."
        case .outputExists(let path):
            "Output already exists at '\(path)'. Pass --overwrite to replace it."
        }
    }
}
