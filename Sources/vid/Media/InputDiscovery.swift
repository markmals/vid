import Foundation

struct InputDiscovery: Sendable {
    func mediaFiles(at paths: [String], recursive: Bool) throws -> [URL] {
        var filesByPath: [String: URL] = [:]

        for path in paths {
            let input = FilePathResolver.resolve(path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory)
            else {
                throw VidError.fileDoesNotExist(path)
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

        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: options,
            )
        else {
            return []
        }

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
