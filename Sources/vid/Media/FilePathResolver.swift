import Foundation

enum FilePathResolver {
    static func resolve(_ path: String) -> URL {
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
