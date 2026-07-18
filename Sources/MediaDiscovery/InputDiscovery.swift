import Foundation

/// Discovers media files beneath user-supplied file and directory paths.
public struct InputDiscovery: Sendable {
    /// Creates a media input discovery service.
    public init() {}

    /// Collects the media files addressed by the supplied paths.
    ///
    /// Each path is resolved to an absolute URL. A path referring to a directory
    /// contributes its contained media files (optionally recursing); a path
    /// referring to a file contributes that file directly. Duplicate files are
    /// collapsed by resolved path.
    /// - Parameters:
    ///   - paths: The raw file or directory paths to search.
    ///   - recursive: Whether directory paths are searched recursively.
    ///   - supportedExtensions: Lowercased extensions accepted as media.
    /// - Returns: The discovered media file URLs, sorted ascending by path.
    /// - Throws: ``MediaDiscoveryError/fileDoesNotExist(path:)`` if a supplied
    ///   path does not exist, or ``MediaDiscoveryError/noInputFiles`` if no
    ///   supported files are found.
    public func mediaFiles(
        at paths: [String],
        recursive: Bool,
        supportedExtensions: Set<String> = Self.mediaExtensions,
    ) throws -> [URL] {
        var filesByPath: [String: URL] = [:]

        for path in paths {
            let input = FilePathResolver.resolvedURL(for: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory)
            else {
                throw MediaDiscoveryError.fileDoesNotExist(path: path)
            }

            if isDirectory.boolValue {
                for file in try files(
                    in: input,
                    recursive: recursive,
                    supportedExtensions: supportedExtensions
                ) {
                    filesByPath[file.path] = file
                }
            } else if supportedExtensions.contains(input.pathExtension.lowercased()) {
                filesByPath[input.path] = input
            }
        }

        let files = filesByPath.values.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        guard !files.isEmpty else {
            throw MediaDiscoveryError.noInputFiles
        }
        return files
    }

    private func files(
        in directory: URL,
        recursive: Bool,
        supportedExtensions: Set<String>,
    ) throws -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        let options: FileManager.DirectoryEnumerationOptions =
            recursive
            ? [.skipsHiddenFiles]
            : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]

        // The caller verifies that `directory` is an existing file URL.
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: options,
        )!

        var files: [URL] = []
        for case let file as URL in enumerator {
            let resourceValues = try file.resourceValues(forKeys: resourceKeys)
            guard resourceValues.isRegularFile == true,
                supportedExtensions.contains(file.pathExtension.lowercased())
            else {
                continue
            }
            files.append(file.standardizedFileURL)
        }
        return files
    }

    /// Lowercased file extensions included by default during discovery.
    public static let mediaExtensions: Set<String> = [
        "3gp",
        "avi",
        "flv",
        "m2ts",
        "m4v",
        "mkv",
        "mov",
        "mp4",
        "mpeg",
        "mpg",
        "mts",
        "ts",
        "webm",
        "wmv",
    ]
}
