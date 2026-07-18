import Foundation

/// Converts user-supplied path strings into fully resolved file URLs.
public enum FilePathResolver {
    /// Resolves a path string into a standardized absolute file URL.
    ///
    /// Expands a leading tilde to the user's home directory. Absolute paths are
    /// used directly; relative paths are resolved against the current working
    /// directory. The result is standardized to remove `.` and `..` components.
    /// - Parameter path: The raw path string, which may contain a leading tilde
    ///   and may be absolute or relative.
    /// - Returns: A standardized absolute file URL for `path`.
    public static func resolvedURL(for path: String) -> URL {
        let expandedPath = NSString(string: path).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath).standardizedFileURL
        }

        return URL(
            fileURLWithPath: expandedPath,
            relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        ).standardizedFileURL
    }
}
