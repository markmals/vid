import Foundation

/// Errors produced while resolving and discovering media files.
public enum MediaDiscoveryError: Error, LocalizedError, Sendable {
    /// No file or directory exists at the supplied path.
    case fileDoesNotExist(path: String)
    /// None of the supplied paths matched a supported file.
    case noInputFiles

    /// A concise description suitable for command-line display.
    public var errorDescription: String? {
        switch self {
        case .fileDoesNotExist(let path):
            "No file or directory exists at '\(path)'."
        case .noInputFiles:
            "No media files matched the supplied paths."
        }
    }
}
