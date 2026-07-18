import Foundation

/// Discovers media files beneath user-supplied file and directory paths.
struct InputDiscovery: Sendable {
    /// Collects the media files addressed by the supplied paths.
    ///
    /// Each path is resolved to an absolute URL. A path referring to a directory
    /// contributes its contained media files (optionally recursing); a path
    /// referring to a file contributes that file directly. Duplicate files are
    /// collapsed by resolved path.
    /// - Parameters:
    ///   - paths: The raw file or directory paths to search.
    ///   - recursive: Whether directory paths are searched recursively.
    /// - Returns: The discovered media file URLs, sorted ascending by path using
    ///   a localized standard comparison.
    /// - Throws: ``VidError/fileDoesNotExist(path:)`` if a supplied path does not
    ///   exist, or ``VidError/noInputFiles`` if no media files are found.
    func mediaFiles(at paths: [String], recursive: Bool) throws -> [URL] {
        var filesByPath: [String: URL] = [:]

        for path in paths {
            let input = FilePathResolver.resolvedURL(for: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory)
            else {
                throw VidError.fileDoesNotExist(path: path)
            }

            if isDirectory.boolValue {
                for file in try files(in: input, recursive: recursive) {
                    filesByPath[file.path] = file
                }
            } else {
                filesByPath[input.path] = input
            }
        }

        let files = filesByPath.values.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
        guard !files.isEmpty else {
            throw VidError.noInputFiles
        }
        return files
    }

    private func files(in directory: URL, recursive: Bool) throws -> [URL] {
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
                Self.mediaExtensions.contains(file.pathExtension.lowercased())
            else {
                continue
            }
            files.append(file.standardizedFileURL)
        }
        return files
    }

    private static let mediaExtensions: Set<String> = [
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
