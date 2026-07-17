import Foundation

enum VidError: Error, LocalizedError {
    case emptyOutput(String)
    case fileDoesNotExist(String)
    case invalidOutputDirectory(String)
    case noInputFiles
    case noVideoStream(String)
    case outputExists(String)
    case processFailed(tool: String, status: String, diagnostic: String?)
    case unreadableProbe(String)

    var errorDescription: String? {
        switch self {
        case .emptyOutput(let path):
            "FFmpeg did not create a non-empty output at '\(path)'."
        case .fileDoesNotExist(let path):
            "No file or directory exists at '\(path)'."
        case .invalidOutputDirectory(let path):
            "The output directory '\(path)' does not exist or is not a directory."
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
