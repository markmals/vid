import Foundation

/// Errors surfaced by the `vid` tool, with user-facing descriptions.
enum VidError: Error, LocalizedError {
    /// FFmpeg completed but produced no non-empty output file.
    /// - Parameter path: The path where the missing or empty output was expected.
    case emptyOutput(path: String)
    /// No file or directory exists at the supplied input path.
    /// - Parameter path: The input path that could not be found.
    case fileDoesNotExist(path: String)
    /// The requested output directory is missing or is not a directory.
    /// - Parameter path: The path that was expected to be an existing directory.
    case invalidOutputDirectory(path: String)
    /// The supplied output options conflict and cannot be satisfied together.
    /// - Parameter reason: A human-readable explanation of the conflict.
    case incompatibleOutputOptions(reason: String)
    /// None of the supplied paths matched any media files.
    case noInputFiles
    /// The input file does not contain a video stream.
    /// - Parameter path: The path of the file lacking a video stream.
    case noVideoStream(path: String)
    /// An output file already exists and overwriting was not requested.
    /// - Parameter path: The path of the existing output file.
    case outputExists(path: String)
    /// A spawned tool exited with a non-zero termination status.
    /// - Parameters:
    ///   - tool: The name of the tool that failed.
    ///   - status: A description of the tool's termination status.
    ///   - diagnostic: The tool's captured diagnostic output, if any.
    case processFailed(tool: String, status: String, diagnostic: String?)
    /// ffprobe returned media information that could not be decoded.
    /// - Parameter path: The path of the file whose probe output was invalid.
    case unreadableProbe(path: String)

    /// A user-facing description of the error.
    var errorDescription: String? {
        switch self {
        case .emptyOutput(let path):
            "FFmpeg did not create a non-empty output at '\(path)'."
        case .fileDoesNotExist(let path):
            "No file or directory exists at '\(path)'."
        case .invalidOutputDirectory(let path):
            "The output directory '\(path)' does not exist or is not a directory."
        case .incompatibleOutputOptions(let reason):
            "Incompatible output options: \(reason)"
        case .noInputFiles:
            "No media files matched the supplied paths."
        case .noVideoStream(let path):
            "'\(path)' does not contain a video stream."
        case .outputExists(let path):
            "Output already exists at '\(path)'. Pass --overwrite to replace it."
        case .processFailed(let tool, let status, let diagnostic):
            if let diagnostic, !diagnostic.isEmpty {
                "\(tool) \(status): \(diagnostic)"
            } else {
                "\(tool) \(status)."
            }
        case .unreadableProbe(let path):
            "ffprobe returned invalid media information for '\(path)'."
        }
    }
}
