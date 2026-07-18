import Foundation

/// Errors produced while decoding ffprobe metadata.
public enum MediaProbeError: Error, LocalizedError, Sendable {
    /// ffprobe returned output that does not match the requested JSON schema.
    case unreadableProbe(path: String)

    /// A concise description suitable for command-line display.
    ///
    /// - Complexity: O(n), where n is the length of the associated path.
    public var errorDescription: String? {
        switch self {
        case .unreadableProbe(let path):
            "ffprobe returned invalid media information for '\(path)'."
        }
    }
}
