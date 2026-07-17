import ArgumentParser
import Foundation

struct MediaInputOptions: ParsableArguments {
    @Argument(help: "One or more media files or directories.")
    var paths: [String] = []

    @Flag(name: .shortAndLong, help: "Descend into supplied directories.")
    var recursive = false

    func files() throws -> [URL] {
        guard !paths.isEmpty else {
            throw ValidationError("Provide at least one media file or directory.")
        }
        return try InputDiscovery().mediaFiles(at: paths, recursive: recursive)
    }
}

struct MediaOutputOptions: ParsableArguments {
    @Option(name: .long, help: "Write outputs to this existing directory.")
    var outputDirectory: String?

    @Flag(
        name: .long,
        help: "Replace an MP4 input in place and remove other source containers after success.")
    var replace = false

    @Flag(name: .long, help: "Permanently remove each source after its output is complete.")
    var removeSource = false

    @Flag(name: .long, help: "Replace existing output and extracted subtitle files.")
    var overwrite = false

    func policy() throws -> OutputPolicy {
        if replace, outputDirectory != nil {
            throw ValidationError("--replace cannot be combined with --output-directory.")
        }

        return OutputPolicy(
            outputDirectory: outputDirectory.map(FilePathResolver.resolve),
            overwrite: overwrite,
            removeSource: removeSource,
            replace: replace,
        )
    }
}

enum AudioCodecArgument: String, CaseIterable, ExpressibleByArgument {
    case aac
    case copy
    case eac3

    func encoding(bitrate: String) -> AudioEncoding {
        switch self {
        case .aac: .aac(bitrate: bitrate)
        case .copy: .copy
        case .eac3: .eac3(bitrate: bitrate)
        }
    }
}

enum SubtitleHandlingArgument: String, CaseIterable, ExpressibleByArgument {
    case extract
    case none
    case text

    var handling: SubtitleHandling {
        switch self {
        case .extract: .extractBitmap
        case .none: .none
        case .text: .textOnly
        }
    }
}
